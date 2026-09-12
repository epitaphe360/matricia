-- Align Client Admin read access with the hardened P08 credit commands.
drop policy if exists credit_wallets_tenant_read on public.credit_wallets;
create policy credit_wallets_tenant_read on public.credit_wallets for select to authenticated
using(
 private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING'])
 or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'])
);

drop policy if exists credit_entries_tenant_read on public.credit_ledger_entries;
create policy credit_entries_tenant_read on public.credit_ledger_entries for select to authenticated
using(
 private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING'])
 or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR'])
);

notify pgrst,'reload schema';
