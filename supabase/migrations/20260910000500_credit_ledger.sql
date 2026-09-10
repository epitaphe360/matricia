create table public.credit_wallets (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  wallet_type text not null check (wallet_type in ('CLIENT','PROVIDER','FRANCHISE')),
  unit_code text not null default 'MATRICIA_CREDIT',
  created_at timestamptz not null default now(),
  unique (organization_id, wallet_type),
  unique (organization_id, id)
);

create table public.credit_ledger_entries (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  wallet_id uuid not null,
  entry_type text not null check (entry_type in ('GRANT','RESERVE','RELEASE','CONSUME','EXPIRE','ADJUSTMENT')),
  quantity bigint not null check (quantity <> 0),
  idempotency_scope text not null,
  idempotency_key text not null,
  correlation_id uuid not null,
  reference_type text not null,
  reference_id text not null,
  occurred_at timestamptz not null default clock_timestamp(),
  created_by uuid not null references auth.users(id),
  foreign key (organization_id, wallet_id) references public.credit_wallets(organization_id, id),
  unique (organization_id, idempotency_scope, idempotency_key)
);

create view public.credit_wallet_balances with (security_invoker = true) as
select wallet.organization_id, wallet.id as wallet_id, wallet.wallet_type, wallet.unit_code,
       coalesce(sum(entry.quantity), 0)::bigint as balance
from public.credit_wallets wallet
left join public.credit_ledger_entries entry on entry.organization_id = wallet.organization_id and entry.wallet_id = wallet.id
group by wallet.organization_id, wallet.id, wallet.wallet_type, wallet.unit_code;

create trigger credit_wallets_immutable before update or delete on public.credit_wallets for each row execute function private.prevent_update_delete();
create trigger credit_ledger_entries_immutable before update or delete on public.credit_ledger_entries for each row execute function private.prevent_update_delete();
alter table public.credit_wallets enable row level security;
alter table public.credit_ledger_entries enable row level security;
revoke all on public.credit_wallets, public.credit_ledger_entries from anon, authenticated;
grant select on public.credit_wallets, public.credit_ledger_entries, public.credit_wallet_balances to authenticated;
create policy credit_wallets_tenant_read on public.credit_wallets for select to authenticated using (private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING']) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy credit_entries_tenant_read on public.credit_ledger_entries for select to authenticated using (private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING']) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create index credit_ledger_wallet_time_idx on public.credit_ledger_entries (organization_id, wallet_id, occurred_at desc, id desc);
