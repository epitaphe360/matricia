begin;

create or replace function public.process_verified_subscription_payment(
  p_gateway text,
  p_provider_event_id text,
  p_provider_intent_id text,
  p_event_type text,
  p_amount_minor bigint,
  p_currency char(3),
  p_paid_at timestamptz,
  p_payment_reference text,
  p_payload_hash text,
  p_signature_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, extensions
as $$
declare
  intent public.subscription_payment_intents%rowtype;
  payment_event public.subscription_payment_events%rowtype;
  subscription public.subscriptions%rowtype;
  plan public.subscription_plan_versions%rowtype;
  expected_amount bigint;
  cycle_number integer;
  period_end timestamptz;
  cash_account_id uuid;
  revenue_account_id uuid;
  journal_id uuid := extensions.gen_random_uuid();
  result jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'PAYMENT_EVENT_PROCESS_DENIED' using errcode = '42501';
  end if;
  if p_gateway is null or p_gateway not in ('DEMO','CMI','PAYPAL') or p_event_type is distinct from 'PAYMENT_SUCCEEDED'
    or length(coalesce(p_provider_event_id,'')) not between 8 and 200
    or length(coalesce(p_provider_intent_id,'')) not between 8 and 200
    or p_amount_minor is null or p_amount_minor <= 0
    or p_currency is null or p_currency !~ '^[A-Z]{3}$'
    or length(btrim(coalesce(p_payment_reference,''))) not between 3 and 200
    or p_payload_hash !~ '^[0-9a-f]{64}$'
    or p_signature_fingerprint !~ '^[0-9a-f]{64}$'
    or p_paid_at is null
    or p_paid_at > clock_timestamp() + interval '5 minutes' then
    raise exception 'INVALID_VERIFIED_PAYMENT_EVENT' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_gateway || ':' || p_provider_event_id, 0));
  select payment_intent.* into intent
  from public.subscription_payment_intents payment_intent
  where payment_intent.gateway=p_gateway and payment_intent.provider_intent_id=p_provider_intent_id
  for update;
  if not found then raise exception 'PAYMENT_INTENT_NOT_FOUND' using errcode = 'P0002'; end if;
  if intent.gateway is distinct from p_gateway or intent.amount_minor is distinct from p_amount_minor or intent.currency is distinct from p_currency then
    raise exception 'VERIFIED_PAYMENT_AMOUNT_MISMATCH' using errcode = '23514';
  end if;
  if p_paid_at < intent.created_at - interval '5 minutes' then
    raise exception 'PAYMENT_EVENT_PREDATES_INTENT' using errcode = '23514';
  end if;

  select stored_event.* into payment_event
  from public.subscription_payment_events stored_event
  where stored_event.gateway=p_gateway and stored_event.provider_event_id=p_provider_event_id;
  if found then
    if payment_event.payment_intent_id <> intent.id
      or payment_event.provider_intent_id is distinct from p_provider_intent_id
      or payment_event.payload_hash is distinct from p_payload_hash
      or payment_event.amount_minor is distinct from p_amount_minor
      or payment_event.currency is distinct from p_currency then
      raise exception 'PAYMENT_EVENT_REPLAY_MISMATCH' using errcode = '22000';
    end if;
    return payment_event.activation_result || jsonb_build_object('replayed',true);
  end if;

  select stored_subscription.* into subscription
  from public.subscriptions stored_subscription
  where stored_subscription.organization_id=intent.organization_id
  for update;
  if not found or subscription.status not in ('TRIAL_ACTIVE','TRIAL_EXPIRED','PAST_DUE','SUSPENDED') then
    raise exception 'SUBSCRIPTION_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  select plan_version.* into plan
  from public.subscription_plan_versions plan_version
  where plan_version.id=intent.plan_version_id and plan_version.status='ACTIVE'
    and plan_version.valid_from<=p_paid_at::date and (plan_version.valid_to is null or plan_version.valid_to>=p_paid_at::date);
  if not found then raise exception 'ACTIVE_PLAN_VERSION_REQUIRED' using errcode = '23514'; end if;
  expected_amount := case when intent.billing_interval='MONTHLY' then plan.monthly_price_minor else plan.annual_price_minor end;
  if expected_amount <> intent.amount_minor or plan.currency <> intent.currency then
    raise exception 'PAYMENT_PLAN_SNAPSHOT_MISMATCH' using errcode = '23514';
  end if;

  insert into public.financial_accounts(organization_id,code,name,account_type,currency)
  values
    (intent.organization_id,'PAYMENT_CASH_'||btrim(intent.currency::text),'Subscription payment cash '||btrim(intent.currency::text),'ASSET',intent.currency),
    (intent.organization_id,'SUBSCRIPTION_REVENUE_'||btrim(intent.currency::text),'Subscription revenue '||btrim(intent.currency::text),'REVENUE',intent.currency)
  on conflict(organization_id,code) do nothing;
  select financial_account.id into cash_account_id
  from public.financial_accounts financial_account
  where financial_account.organization_id=intent.organization_id
    and financial_account.code='PAYMENT_CASH_'||btrim(intent.currency::text)
    and financial_account.account_type='ASSET' and financial_account.currency=intent.currency;
  select financial_account.id into revenue_account_id
  from public.financial_accounts financial_account
  where financial_account.organization_id=intent.organization_id
    and financial_account.code='SUBSCRIPTION_REVENUE_'||btrim(intent.currency::text)
    and financial_account.account_type='REVENUE' and financial_account.currency=intent.currency;
  if cash_account_id is null or revenue_account_id is null then
    raise exception 'SUBSCRIPTION_LEDGER_ACCOUNTS_INVALID' using errcode='23514';
  end if;
  insert into public.financial_journals(
    id,organization_id,journal_type,currency,idempotency_scope,idempotency_key,
    correlation_id,effective_at,description,created_by
  ) values (
    journal_id,intent.organization_id,'SUBSCRIPTION_PAYMENT',intent.currency,
    'subscription.payment',p_gateway||':'||p_provider_event_id,p_correlation_id,p_paid_at,
    'Verified subscription payment',intent.created_by
  );
  insert into public.financial_entries(organization_id,journal_id,account_id,direction,amount_minor,currency)
  values
    (intent.organization_id,journal_id,cash_account_id,'DEBIT',intent.amount_minor,intent.currency),
    (intent.organization_id,journal_id,revenue_account_id,'CREDIT',intent.amount_minor,intent.currency);
  insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(intent.organization_id,'SERVICE','financial.journal.posted','financial_journal',journal_id::text,p_correlation_id,
    jsonb_build_object('journal_type','SUBSCRIPTION_PAYMENT','currency',intent.currency,'debit_minor',intent.amount_minor),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(intent.organization_id,'financial_journal',journal_id::text,'FinancialJournalPostedV1',p_correlation_id,
    jsonb_build_object('journal_id',journal_id,'organization_id',intent.organization_id,'currency',intent.currency,'debit_minor',intent.amount_minor),
    'finance:'||p_gateway||':'||p_provider_event_id);

  period_end := case when intent.billing_interval='MONTHLY' then p_paid_at + interval '1 month' else p_paid_at + interval '1 year' end;
  select coalesce(max(subscription_cycle.cycle_number),0)+1 into cycle_number
  from public.subscription_cycles subscription_cycle
  where subscription_cycle.subscription_id=subscription.id;
  insert into public.subscription_cycles(subscription_id,organization_id,plan_version_id,cycle_number,period_start,period_end,currency,amount_minor,payment_reference,payment_proof_hash,correlation_id)
  values(subscription.id,intent.organization_id,plan.id,cycle_number,p_paid_at,period_end,intent.currency,intent.amount_minor,p_payment_reference,p_payload_hash,p_correlation_id);
  update public.subscriptions set plan_version_id=plan.id,pending_plan_version_id=null,status='ACTIVE',billing_interval=intent.billing_interval,current_period_start=p_paid_at,current_period_end=period_end,pending_change_effective_at=null,row_version=row_version+1,updated_at=clock_timestamp() where id=subscription.id;
  insert into public.subscription_state_events(subscription_id,organization_id,from_status,to_status,reason_code,idempotency_key,correlation_id,actor_user_id)
  values(subscription.id,intent.organization_id,subscription.status,'ACTIVE','VERIFIED_PAYMENT',p_provider_event_id,p_correlation_id,intent.created_by);
  result := jsonb_build_object('outcome','SUBSCRIPTION_ACTIVATED','subscription_id',subscription.id,'payment_intent_id',intent.id,'provider_event_id',p_provider_event_id,'financial_journal_id',journal_id,'cycle_number',cycle_number,'period_end',period_end,'amount_minor',intent.amount_minor,'currency',intent.currency,'replayed',false);
  insert into public.subscription_payment_events(
    payment_intent_id,organization_id,gateway,provider_event_id,provider_intent_id,event_type,
    amount_minor,currency,paid_at,payment_reference,payload_hash,signature_fingerprint,
    activation_result,correlation_id
  ) values (
    intent.id,intent.organization_id,p_gateway,p_provider_event_id,p_provider_intent_id,p_event_type,
    p_amount_minor,p_currency,p_paid_at,p_payment_reference,p_payload_hash,p_signature_fingerprint,
    result,p_correlation_id
  );
  insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(intent.organization_id,'SERVICE','subscription.activated_from_verified_payment','subscription',subscription.id::text,p_correlation_id,jsonb_build_object('payment_intent_id',intent.id,'provider_event_id',p_provider_event_id,'gateway',p_gateway,'cycle_number',cycle_number),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(intent.organization_id,'subscription',subscription.id::text,'SubscriptionPaidV1',p_correlation_id,result,p_gateway || ':' || p_provider_event_id);
  return result;
end
$$;

revoke all on function public.process_verified_subscription_payment(text,text,text,text,bigint,character,timestamptz,text,text,text,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.process_verified_subscription_payment(text,text,text,text,bigint,character,timestamptz,text,text,text,uuid)
  to service_role;

commit;
