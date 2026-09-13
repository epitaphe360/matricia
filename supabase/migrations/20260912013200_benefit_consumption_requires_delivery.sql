begin;

create or replace function public.consume_benefit_credits(
  p_redemption_id uuid,
  p_delivery_proof_hash text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  d public.benefit_redemptions%rowtype;
  h text;
  r jsonb;
  release_entry bigint;
  consume_entry bigint;
  x record;
begin
  select * into d from public.benefit_redemptions where id = p_redemption_id for update;
  if a is null or not found or not private.credits_client_access(d.organization_id, a) then
    raise exception 'CREDIT_CONSUME_DENIED' using errcode = '42501';
  end if;

  h := private.canonical_request_hash(jsonb_build_object('redemption', d.id, 'proof_hash', p_delivery_proof_hash));
  r := private.begin_credit_command(d.organization_id, 'credits.benefit.consume', p_idempotency_key, h, a);
  if r is not null then return r; end if;

  if d.status <> 'DELIVERED' or p_delivery_proof_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'REDEMPTION_NOT_CONSUMABLE' using errcode = '55000';
  end if;

  for x in
    select credit_lot_id, quantity
    from public.credit_lot_movements
    where redemption_id = d.id and movement_type = 'RESERVE'
  loop
    insert into public.credit_lot_movements(
      organization_id, credit_lot_id, redemption_id, movement_type, quantity,
      idempotency_scope, idempotency_key, correlation_id, created_by
    ) values (
      d.organization_id, x.credit_lot_id, d.id, 'CONSUME', x.quantity,
      'credits.benefit.consume', p_idempotency_key, p_correlation_id, a
    );
  end loop;

  insert into public.credit_ledger_entries(
    organization_id, wallet_id, entry_type, quantity, idempotency_scope,
    idempotency_key, correlation_id, reference_type, reference_id, created_by
  ) values (
    d.organization_id, d.wallet_id, 'RELEASE', d.reserved_credits,
    'credits.benefit.consume.release', p_idempotency_key, p_correlation_id,
    'BENEFIT_REDEMPTION', d.id::text, a
  ) returning id into release_entry;

  insert into public.credit_ledger_entries(
    organization_id, wallet_id, entry_type, quantity, idempotency_scope,
    idempotency_key, correlation_id, reference_type, reference_id, created_by
  ) values (
    d.organization_id, d.wallet_id, 'CONSUME', -d.reserved_credits,
    'credits.benefit.consume', p_idempotency_key, p_correlation_id,
    'BENEFIT_REDEMPTION', d.id::text, a
  ) returning id into consume_entry;

  update public.benefit_redemptions
  set status = 'CONSUMED', delivery_proof_hash = p_delivery_proof_hash,
      updated_at = clock_timestamp(), row_version = row_version + 1
  where id = d.id;

  insert into public.benefit_redemption_events(
    organization_id, redemption_id, from_status, to_status, reason_code,
    proof_hash, idempotency_key, correlation_id, actor_user_id
  ) values (
    d.organization_id, d.id, d.status, 'CONSUMED', 'DELIVERY_PROVED',
    p_delivery_proof_hash, p_idempotency_key, p_correlation_id, a
  );

  r := jsonb_build_object(
    'outcome', 'BENEFIT_CONSUMED', 'redemption_id', d.id,
    'consume_entry_id', consume_entry, 'consumed_credits', d.reserved_credits
  );

  insert into public.audit_events(
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, event_hash
  ) values (
    d.organization_id, a, 'USER', 'benefit.consumed', 'benefit_redemption',
    d.id::text, p_correlation_id, r, repeat('0', 64)
  );

  insert into public.event_outbox(
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload, idempotency_key
  ) values (
    d.organization_id, 'benefit_redemption', d.id::text,
    'BenefitConsumedV1', p_correlation_id, r, p_idempotency_key
  );

  perform private.finish_credit_command(
    d.organization_id, 'credits.benefit.consume', p_idempotency_key, r
  );
  return r;
end
$$;

revoke all on function public.consume_benefit_credits(uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.consume_benefit_credits(uuid, text, text, uuid)
  to authenticated;

commit;
