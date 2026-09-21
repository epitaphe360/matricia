-- Client invoice read: the historical cycle projection exposes the payment
-- reference already stored on the immutable cycle. The proof hash stays server-side.

create or replace function public.get_client_subscription_historical_plan_projection(
  p_subscription_id uuid,
  p_cycle_limit integer default 24
)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  subscription public.subscriptions%rowtype;
  cycle_projection jsonb;
begin
  select candidate.*
  into subscription
  from public.subscriptions candidate
  where candidate.id = p_subscription_id;

  if actor is null
    or subscription.id is null
    or not private.has_org_role(
      subscription.organization_id,
      array['CLIENT_OWNER', 'CLIENT_ADMIN', 'CLIENT_ACCOUNTING', 'CLIENT_VIEWER'],
      actor
    )
  then
    raise exception 'SUBSCRIPTION_HISTORY_ACCESS_DENIED' using errcode = '42501';
  end if;

  if p_cycle_limit is null or p_cycle_limit not between 1 and 24 then
    raise exception 'SUBSCRIPTION_HISTORY_LIMIT_INVALID' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(projected.payload order by projected.cycle_number desc), '[]'::jsonb)
  into cycle_projection
  from (
    select
      cycle.cycle_number,
      jsonb_build_object(
        'id', cycle.id,
        'cycle_number', cycle.cycle_number,
        'period_start', cycle.period_start,
        'period_end', cycle.period_end,
        'currency', cycle.currency,
        'amount_minor', cycle.amount_minor::text,
        'payment_reference', cycle.payment_reference,
        'plan', private.project_subscription_plan_version(cycle_version.id)
      ) as payload
    from public.subscription_cycles cycle
    join public.subscription_plan_versions cycle_version
      on cycle_version.id = cycle.plan_version_id
     and cycle_version.status in ('ACTIVE', 'RETIRED')
    where cycle.subscription_id = subscription.id
      and cycle.organization_id = subscription.organization_id
    order by cycle.cycle_number desc
    limit p_cycle_limit
  ) projected;

  return jsonb_build_object(
    'subscription_id', subscription.id,
    'organization_id', subscription.organization_id,
    'current_plan', private.project_subscription_plan_version(subscription.plan_version_id),
    'pending_plan', private.project_subscription_plan_version(subscription.pending_plan_version_id),
    'cycles', cycle_projection
  );
end
$$;

revoke all on function public.get_client_subscription_historical_plan_projection(uuid, integer)
from public, anon, authenticated, service_role;
grant execute on function public.get_client_subscription_historical_plan_projection(uuid, integer)
to authenticated;

notify pgrst, 'reload schema';
