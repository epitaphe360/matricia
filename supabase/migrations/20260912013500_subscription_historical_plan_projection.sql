-- Tenant-safe historical subscription projection for CL-041.
-- A client can only resolve ACTIVE/RETIRED plan versions already linked to its own
-- subscription aggregate (current/pending) or immutable paid cycles.

create function private.project_subscription_plan_version(p_plan_version_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'id', version.id,
    'plan_id', version.plan_id,
    'code', plan.code,
    'version', version.version,
    'status', version.status,
    'currency', version.currency,
    'monthly_price_minor', version.monthly_price_minor::text,
    'annual_price_minor', version.annual_price_minor::text,
    'monthly_credit_grant', version.monthly_credit_grant::text,
    'core_allocation_basis_points', version.core_allocation_basis_points,
    'benefit_pool_allocation_basis_points', version.benefit_pool_allocation_basis_points,
    'limits_snapshot', version.limits_snapshot,
    'box_version_reference', version.box_version_reference,
    'valid_from', version.valid_from,
    'valid_to', version.valid_to,
    'content_hash', version.content_hash,
    'entitlements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'code', entitlement.entitlement_code,
          'enabled', entitlement.enabled,
          'quota_value', entitlement.quota_value::text,
          'configuration', entitlement.configuration
        )
        order by entitlement.entitlement_code
      )
      from public.plan_entitlements entitlement
      where entitlement.plan_version_id = version.id
    ), '[]'::jsonb)
  )
  from public.subscription_plan_versions version
  join public.subscription_plans plan on plan.id = version.plan_id
  where version.id = p_plan_version_id
    and version.status in ('ACTIVE', 'RETIRED')
$$;

create function public.get_client_subscription_historical_plan_projection(
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

revoke all on function private.project_subscription_plan_version(uuid)
from public, anon, authenticated, service_role;

revoke all on function public.get_client_subscription_historical_plan_projection(uuid, integer)
from public, anon, authenticated, service_role;

grant execute on function public.get_client_subscription_historical_plan_projection(uuid, integer)
to authenticated;
