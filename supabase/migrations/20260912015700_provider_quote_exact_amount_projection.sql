-- P07: expose quote totals as text without bypassing tenant RLS or JavaScript precision limits.

create or replace function public.list_provider_quote_version_amounts(
  p_provider_organization_id uuid,
  p_quote_version_ids uuid[]
) returns table(
  id uuid,
  version_number integer,
  currency text,
  subtotal_minor text,
  tax_minor text,
  total_minor text
)
language sql
stable
security invoker
set search_path=pg_catalog,public,private
as $$
  select version.id,version.version_number,version.currency::text,
    version.subtotal_minor::text,version.tax_minor::text,version.total_minor::text
  from public.quote_versions version
  where version.provider_organization_id=p_provider_organization_id
    and version.id=any(p_quote_version_ids)
    and coalesce(cardinality(p_quote_version_ids),0) between 1 and 100
    and exists(
      select 1
      from public.organization_memberships membership
      join public.organization_member_roles member_role
        on member_role.membership_id=membership.id
       and member_role.revoked_at is null
      where membership.organization_id=p_provider_organization_id
        and membership.user_id=auth.uid()
        and membership.status='ACTIVE'
        and member_role.role_code in(
          'PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES','PROVIDER_VIEWER'
        )
    )
  order by version.id;
$$;

revoke all on function public.list_provider_quote_version_amounts(uuid,uuid[]) from public,anon,service_role;
grant execute on function public.list_provider_quote_version_amounts(uuid,uuid[]) to authenticated;
