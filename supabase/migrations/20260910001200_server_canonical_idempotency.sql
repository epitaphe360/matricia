create or replace function private.canonical_request_hash(p_payload jsonb)
returns text
language sql
immutable
strict
security invoker
set search_path = pg_catalog, extensions
as $$
  select encode(extensions.digest(convert_to(p_payload::text,'UTF8'),'sha256'),'hex')
$$;
revoke all on function private.canonical_request_hash(jsonb) from public, anon, authenticated, service_role;

create or replace function public.post_financial_journal(
  p_organization_id uuid,
  p_idempotency_key text,
  p_request_hash text,
  p_journal_type text,
  p_currency char(3),
  p_effective_at timestamptz,
  p_description text,
  p_entries jsonb,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_journal_id uuid := extensions.gen_random_uuid();
  v_inserted integer;
  v_existing public.idempotency_keys%rowtype;
  v_request_hash text;
  v_canonical_entries jsonb;
  v_debit bigint;
  v_credit bigint;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if not (
    private.has_org_role(p_organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING'], v_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], v_actor)
  ) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if length(p_idempotency_key) not between 8 and 200
     or (p_request_hash is not null and p_request_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'INVALID_IDEMPOTENCY' using errcode='22023';
  end if;
  if p_currency !~ '^[A-Z]{3}$' or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) < 2 then
    raise exception 'INVALID_JOURNAL' using errcode='22023';
  end if;

  perform 1 from public.organizations where id=p_organization_id and status='ACTIVE' for update;
  if not found then raise exception 'ORGANIZATION_NOT_ACTIVE' using errcode='23514'; end if;

  if exists (
    select 1 from jsonb_array_elements(p_entries) item
    where (item->>'direction') not in ('DEBIT','CREDIT')
       or coalesce((item->>'amount_minor')::bigint,0) <= 0
       or not exists (
         select 1 from public.financial_accounts account
         where account.id=(item->>'account_id')::uuid
           and account.organization_id=p_organization_id
           and account.currency=p_currency
       )
  ) then raise exception 'INVALID_JOURNAL_ENTRY' using errcode='23514'; end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'account_id',(item->>'account_id')::uuid,
      'direction',item->>'direction',
      'amount_minor',(item->>'amount_minor')::bigint
    )
    order by (item->>'account_id')::uuid,item->>'direction',(item->>'amount_minor')::bigint
  ),'[]'::jsonb)
  into v_canonical_entries
  from jsonb_array_elements(p_entries) item;

  v_request_hash := private.canonical_request_hash(jsonb_build_object(
    'operation','finance.post_journal.v1',
    'organization_id',p_organization_id,
    'journal_type',p_journal_type,
    'currency',btrim(p_currency::text),
    'effective_at',p_effective_at,
    'description',p_description,
    'entries',v_canonical_entries
  ));
  if p_request_hash is not null and p_request_hash <> v_request_hash then
    raise exception 'CLIENT_REQUEST_HASH_MISMATCH' using errcode='22000';
  end if;

  insert into public.idempotency_keys (organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values (p_organization_id,'finance.post_journal',p_idempotency_key,v_request_hash,v_actor,now()+interval '7 days')
  on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select * into v_existing from public.idempotency_keys
    where organization_id=p_organization_id and operation_scope='finance.post_journal' and key=p_idempotency_key;
    if v_existing.request_hash <> v_request_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return (v_existing.response_body->>'journal_id')::uuid; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;

  select coalesce(sum((item->>'amount_minor')::bigint) filter (where item->>'direction'='DEBIT'),0),
         coalesce(sum((item->>'amount_minor')::bigint) filter (where item->>'direction'='CREDIT'),0)
  into v_debit,v_credit from jsonb_array_elements(p_entries) item;
  if v_debit=0 or v_debit<>v_credit then raise exception 'UNBALANCED_FINANCIAL_JOURNAL' using errcode='23514'; end if;

  insert into public.financial_journals
    (id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,correlation_id,effective_at,description,created_by)
  values
    (v_journal_id,p_organization_id,p_journal_type,p_currency,'finance.post_journal',p_idempotency_key,p_correlation_id,p_effective_at,p_description,v_actor);
  insert into public.financial_entries (organization_id,journal_id,account_id,direction,amount_minor,currency)
  select p_organization_id,v_journal_id,(item->>'account_id')::uuid,item->>'direction',(item->>'amount_minor')::bigint,p_currency
  from jsonb_array_elements(p_entries) item;

  insert into public.audit_events
    (organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values
    (p_organization_id,v_actor,'USER','financial.journal.posted','financial_journal',v_journal_id::text,p_correlation_id,
     jsonb_build_object('currency',p_currency,'debit_minor',v_debit),null,repeat('0',64));
  insert into public.event_outbox (organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values (p_organization_id,'financial_journal',v_journal_id::text,'FinancialJournalPostedV1',p_correlation_id,
          jsonb_build_object('journal_id',v_journal_id,'organization_id',p_organization_id,'currency',p_currency,'debit_minor',v_debit));
  update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=jsonb_build_object('journal_id',v_journal_id),completed_at=clock_timestamp()
  where organization_id=p_organization_id and operation_scope='finance.post_journal' and key=p_idempotency_key;
  return v_journal_id;
end;
$$;

create or replace function public.append_credit_entry(
  p_organization_id uuid,
  p_wallet_id uuid,
  p_entry_type text,
  p_quantity bigint,
  p_reference_type text,
  p_reference_id text,
  p_idempotency_key text,
  p_request_hash text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns bigint
language plpgsql
security definer
set search_path = pg_catalog, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_inserted integer;
  v_existing public.idempotency_keys%rowtype;
  v_entry_id bigint;
  v_balance bigint;
  v_request_hash text;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if not (
    private.has_org_role(p_organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING'], v_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], v_actor)
  ) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if length(p_idempotency_key) not between 8 and 200
     or (p_request_hash is not null and p_request_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'INVALID_IDEMPOTENCY' using errcode='22023';
  end if;
  if p_entry_type not in ('GRANT','RESERVE','RELEASE','CONSUME','EXPIRE','ADJUSTMENT') or p_quantity=0 then
    raise exception 'INVALID_CREDIT_ENTRY' using errcode='22023';
  end if;
  if (p_entry_type in ('GRANT','RELEASE') and p_quantity<0)
     or (p_entry_type in ('RESERVE','CONSUME','EXPIRE') and p_quantity>0) then
    raise exception 'INVALID_CREDIT_SIGN' using errcode='23514';
  end if;

  perform 1 from public.credit_wallets where id=p_wallet_id and organization_id=p_organization_id for update;
  if not found then raise exception 'WALLET_NOT_FOUND' using errcode='P0002'; end if;

  v_request_hash := private.canonical_request_hash(jsonb_build_object(
    'operation','credits.append.v1',
    'organization_id',p_organization_id,
    'wallet_id',p_wallet_id,
    'entry_type',p_entry_type,
    'quantity',p_quantity,
    'reference_type',p_reference_type,
    'reference_id',p_reference_id
  ));
  if p_request_hash is not null and p_request_hash <> v_request_hash then
    raise exception 'CLIENT_REQUEST_HASH_MISMATCH' using errcode='22000';
  end if;

  insert into public.idempotency_keys (organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values (p_organization_id,'credits.append',p_idempotency_key,v_request_hash,v_actor,now()+interval '7 days') on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted=0 then
    select * into v_existing from public.idempotency_keys where organization_id=p_organization_id and operation_scope='credits.append' and key=p_idempotency_key;
    if v_existing.request_hash<>v_request_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return (v_existing.response_body->>'entry_id')::bigint; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;

  insert into public.credit_ledger_entries
    (organization_id,wallet_id,entry_type,quantity,idempotency_scope,idempotency_key,correlation_id,reference_type,reference_id,created_by)
  values
    (p_organization_id,p_wallet_id,p_entry_type,p_quantity,'credits.append',p_idempotency_key,p_correlation_id,p_reference_type,p_reference_id,v_actor)
  returning id into v_entry_id;
  select coalesce(sum(quantity),0)::bigint into v_balance from public.credit_ledger_entries where organization_id=p_organization_id and wallet_id=p_wallet_id;
  if v_balance<0 then raise exception 'INSUFFICIENT_CREDITS' using errcode='23514'; end if;

  insert into public.audit_events
    (organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values
    (p_organization_id,v_actor,'USER','credit.entry.appended','credit_ledger_entry',v_entry_id::text,p_correlation_id,
     jsonb_build_object('entry_type',p_entry_type,'quantity',p_quantity,'balance',v_balance),null,repeat('0',64));
  insert into public.event_outbox (organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
  values (p_organization_id,'credit_wallet',p_wallet_id::text,'CreditLedgerEntryAppendedV1',p_correlation_id,
          jsonb_build_object('entry_id',v_entry_id,'wallet_id',p_wallet_id,'entry_type',p_entry_type,'quantity',p_quantity,'balance',v_balance));
  update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=jsonb_build_object('entry_id',v_entry_id,'balance',v_balance),completed_at=clock_timestamp()
  where organization_id=p_organization_id and operation_scope='credits.append' and key=p_idempotency_key;
  return v_entry_id;
end;
$$;

revoke all on function public.post_financial_journal(uuid,text,text,text,char,timestamptz,text,jsonb,uuid) from public, anon;
revoke all on function public.append_credit_entry(uuid,uuid,text,bigint,text,text,text,text,uuid) from public, anon;
grant execute on function public.post_financial_journal(uuid,text,text,text,char,timestamptz,text,jsonb,uuid) to authenticated;
grant execute on function public.append_credit_entry(uuid,uuid,text,bigint,text,text,text,text,uuid) to authenticated;
