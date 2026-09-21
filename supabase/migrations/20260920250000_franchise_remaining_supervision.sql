-- Franchisee remaining supervision: disputes of mandated-library missions (SELECT only).
-- service_skus ACTIVE remain readable via the existing catalog policy.
-- Additive; client/provider/platform policies stay unchanged.
-- The walk lives in a SECURITY DEFINER helper: a policy join would be hidden by
-- RLS on contract_versions (no franchise policy) and can raise 42702 on sibling ids.

create or replace function private.franchise_supervises_dispute(p_case_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.dispute_cases d
    join public.missions m on m.id = d.mission_id
    where d.id = p_case_id
      and private.franchise_supervises_contract(m.contract_id, p_actor)
  );
$$;

revoke all on function private.franchise_supervises_dispute(uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function private.franchise_supervises_dispute(uuid, uuid) to authenticated;

drop policy if exists dispute_cases_franchise_library_read on public.dispute_cases;
create policy dispute_cases_franchise_library_read on public.dispute_cases
  for select to authenticated
  using (private.franchise_supervises_dispute(dispute_cases.id));

notify pgrst, 'reload schema';
