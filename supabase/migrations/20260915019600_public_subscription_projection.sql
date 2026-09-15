-- Public read-only projection. Rollback: revoke/drop this function and restore
-- the server repository only after confirming the public page has another source.
create function public.get_public_subscription_plans()
returns table(
  id uuid,
  code text,
  currency text,
  monthly_price_minor text,
  annual_price_minor text,
  monthly_credit_grant text
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    version.id,
    plan.code,
    version.currency::text,
    version.monthly_price_minor::text,
    version.annual_price_minor::text,
    version.monthly_credit_grant::text
  from public.subscription_plan_versions version
  join public.subscription_plans plan on plan.id = version.plan_id
  where version.status = 'ACTIVE'
    and plan.status = 'ACTIVE'
    and version.valid_from <= current_date
    and (version.valid_to is null or version.valid_to >= current_date)
    and plan.code in ('PREMIUM', 'GOLD', 'PLATINUM')
  order by version.monthly_price_minor, plan.code
$$;

revoke all on function public.get_public_subscription_plans() from public, anon, authenticated, service_role;
grant execute on function public.get_public_subscription_plans() to anon, authenticated;
