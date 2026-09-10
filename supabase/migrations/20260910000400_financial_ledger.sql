create table public.financial_accounts (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  account_type text not null check (account_type in ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE')),
  currency char(3) not null default 'MAD' check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (organization_id, id)
);

create table public.financial_journals (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  journal_type text not null,
  status text not null default 'POSTED' check (status = 'POSTED'),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  idempotency_scope text not null,
  idempotency_key text not null,
  correlation_id uuid not null,
  effective_at timestamptz not null,
  description text not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (organization_id, id),
  unique (organization_id, idempotency_scope, idempotency_key)
);

create table public.financial_entries (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  journal_id uuid not null,
  account_id uuid not null,
  direction text not null check (direction in ('DEBIT','CREDIT')),
  amount_minor bigint not null check (amount_minor > 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  foreign key (organization_id, journal_id) references public.financial_journals(organization_id, id),
  foreign key (organization_id, account_id) references public.financial_accounts(organization_id, id)
);

create or replace function private.assert_financial_journal_balanced()
returns trigger language plpgsql security invoker set search_path = pg_catalog, public, private as $$
declare debit_total bigint; credit_total bigint;
begin
  select coalesce(sum(amount_minor) filter (where direction='DEBIT'),0),
         coalesce(sum(amount_minor) filter (where direction='CREDIT'),0)
    into debit_total, credit_total
  from public.financial_entries where journal_id = new.journal_id and organization_id = new.organization_id;
  if debit_total = 0 or debit_total <> credit_total then
    raise exception 'UNBALANCED_FINANCIAL_JOURNAL' using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger financial_journal_balanced
after insert or update or delete on public.financial_entries deferrable initially deferred
for each row execute function private.assert_financial_journal_balanced();
create trigger financial_accounts_immutable before update or delete on public.financial_accounts for each row execute function private.prevent_update_delete();
create trigger financial_journals_immutable before update or delete on public.financial_journals for each row execute function private.prevent_update_delete();
create trigger financial_entries_immutable before update or delete on public.financial_entries for each row execute function private.prevent_update_delete();

alter table public.financial_accounts enable row level security;
alter table public.financial_journals enable row level security;
alter table public.financial_entries enable row level security;
revoke all on public.financial_accounts, public.financial_journals, public.financial_entries from anon, authenticated;
grant select on public.financial_accounts, public.financial_journals, public.financial_entries to authenticated;
create policy financial_accounts_tenant_read on public.financial_accounts for select to authenticated using (private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING']) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy financial_journals_tenant_read on public.financial_journals for select to authenticated using (private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING']) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy financial_entries_tenant_read on public.financial_entries for select to authenticated using (private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING']) or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create index financial_journals_tenant_time_idx on public.financial_journals (organization_id, effective_at desc);
create index financial_entries_journal_idx on public.financial_entries (organization_id, journal_id, id);
create index financial_entries_account_idx on public.financial_entries (organization_id, account_id, id);
