drop policy if exists audit_events_tenant_read on public.audit_events;
drop policy if exists event_outbox_tenant_read on public.event_outbox;
revoke all on public.event_outbox from anon, authenticated, service_role;
revoke all on public.audit_events from anon, authenticated, service_role;
grant select on public.audit_events to authenticated;

create policy audit_events_central_read on public.audit_events for select to authenticated
using (private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','FINANCE_MANAGER','DISPUTE_MANAGER','READ_ONLY_AUDITOR']));

create view public.organization_audit_activity with (security_barrier=true) as
select organization_id,id,action,resource_type,resource_id,correlation_id,occurred_at
from public.audit_events
where organization_id is not null and private.is_active_org_member(organization_id);
revoke all on public.organization_audit_activity from public, anon;
grant select on public.organization_audit_activity to authenticated;

revoke update on public.user_profiles from authenticated;
grant update (display_name,preferred_locale) on public.user_profiles to authenticated;

alter function private.is_active_org_member(uuid,uuid) set search_path = pg_catalog, private;
alter function private.has_org_role(uuid,text[],uuid) set search_path = pg_catalog, private;
alter function private.has_platform_role(text[],uuid) set search_path = pg_catalog, private;

alter table public.financial_accounts add constraint financial_accounts_tenant_id_currency_key unique (organization_id,id,currency);
alter table public.financial_journals add constraint financial_journals_tenant_id_currency_key unique (organization_id,id,currency);
alter table public.financial_entries add constraint financial_entries_journal_currency_fk
  foreign key (organization_id,journal_id,currency) references public.financial_journals(organization_id,id,currency);
alter table public.financial_entries add constraint financial_entries_account_currency_fk
  foreign key (organization_id,account_id,currency) references public.financial_accounts(organization_id,id,currency);

create or replace function private.assert_financial_journal_has_entries()
returns trigger language plpgsql security invoker set search_path=pg_catalog as $$
begin
  if not exists (select 1 from public.financial_entries where organization_id=new.organization_id and journal_id=new.id) then
    raise exception 'EMPTY_FINANCIAL_JOURNAL' using errcode='23514';
  end if;
  return null;
end;
$$;
create constraint trigger financial_journal_not_empty after insert on public.financial_journals
deferrable initially deferred for each row execute function private.assert_financial_journal_has_entries();

alter table public.credit_ledger_entries add constraint credit_entry_sign_check check (
  (entry_type in ('GRANT','RELEASE') and quantity>0)
  or (entry_type in ('RESERVE','CONSUME','EXPIRE') and quantity<0)
  or (entry_type='ADJUSTMENT' and quantity<>0)
);
create or replace function private.assert_credit_wallet_nonnegative()
returns trigger language plpgsql security invoker set search_path=pg_catalog as $$
begin
  if (select coalesce(sum(quantity),0) from public.credit_ledger_entries where organization_id=new.organization_id and wallet_id=new.wallet_id)<0 then
    raise exception 'NEGATIVE_CREDIT_BALANCE' using errcode='23514';
  end if;
  return null;
end;
$$;
create constraint trigger credit_wallet_nonnegative after insert on public.credit_ledger_entries
deferrable initially deferred for each row execute function private.assert_credit_wallet_nonnegative();

revoke insert,update,delete on public.idempotency_keys,public.audit_events,public.event_outbox,
  public.financial_accounts,public.financial_journals,public.financial_entries,
  public.credit_wallets,public.credit_ledger_entries from service_role;

alter table public.event_outbox add constraint event_outbox_lock_pair_check
  check ((locked_at is null)=(locked_by is null));
alter table public.event_outbox add constraint event_outbox_terminal_state_check
  check (not (published_at is not null and dead_lettered_at is not null));
drop index if exists public.event_outbox_dispatch_idx;

create or replace function private.seal_audit_event()
returns trigger language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_previous_hash text;
begin
  if new.organization_id is not null then
    perform 1 from public.organizations where id=new.organization_id for update;
    if not found then raise exception 'AUDIT_ORGANIZATION_NOT_FOUND' using errcode='23503'; end if;
    select event_hash into v_previous_hash from public.audit_events where organization_id=new.organization_id order by id desc limit 1;
  else
    perform pg_advisory_xact_lock(hashtextextended('matricia.platform.audit',0));
    select event_hash into v_previous_hash from public.audit_events where organization_id is null order by id desc limit 1;
  end if;
  new.previous_hash:=v_previous_hash;
  new.event_hash:=encode(extensions.digest(convert_to(jsonb_build_object(
    'previous_hash',coalesce(v_previous_hash,''),'organization_id',new.organization_id,'actor_user_id',new.actor_user_id,
    'actor_type',new.actor_type,'action',new.action,'resource_type',new.resource_type,'resource_id',new.resource_id,
    'correlation_id',new.correlation_id,'occurred_at',new.occurred_at,'request_ip',new.request_ip,
    'user_agent',new.user_agent,'metadata',new.metadata
  )::text,'UTF8'),'sha256'),'hex');
  return new;
end;
$$;

do $$
declare target record;
begin
  for target in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_depend d on d.objid=p.oid and d.classid='pg_proc'::regclass
    join pg_extension e on e.oid=d.refobjid
    where e.extname='pgtap'
  loop
    execute format('revoke execute on function %s from public, anon, authenticated, service_role',target.signature);
  end loop;
end;
$$;
