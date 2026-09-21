-- Admin Boxes/P&L/closure/exceptions/volume: versioned offer commands, read dashboards and exception sweep.

create or replace function private.guard_offer_version_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  allowed text[] := array['status', 'effective_to', 'approval_reference'];
begin
  if tg_op = 'DELETE' then
    raise exception 'IMMUTABLE_OFFER_VERSION' using errcode = '55000';
  end if;
  if (to_jsonb(new) - allowed) is distinct from (to_jsonb(old) - allowed) then
    raise exception 'IMMUTABLE_OFFER_VERSION' using errcode = '55000';
  end if;
  if old.status = 'RETIRED' or (old.status = 'ACTIVE' and new.status not in ('ACTIVE', 'PAUSED', 'RETIRED'))
     or (old.status in ('DRAFT', 'UNDER_REVIEW') and new.status not in ('DRAFT', 'UNDER_REVIEW', 'ACTIVE', 'PAUSED', 'RETIRED'))
     or (old.status = 'PAUSED' and new.status not in ('PAUSED', 'ACTIVE', 'RETIRED')) then
    raise exception 'INVALID_OFFER_STATUS_TRANSITION' using errcode = '22023';
  end if;
  return new;
end
$$;

drop trigger if exists benefit_versions_immutable on public.benefit_versions;
drop trigger if exists box_versions_immutable on public.box_versions;
create trigger benefit_versions_immutable before update or delete on public.benefit_versions
  for each row execute function private.guard_offer_version_mutation();
create trigger box_versions_immutable before update or delete on public.box_versions
  for each row execute function private.guard_offer_version_mutation();

create or replace function public.create_benefit_version(
  p_audit_organization_id uuid,
  p_code text,
  p_benefit_type text,
  p_fulfillment_mode text,
  p_name_fr text,
  p_name_ar text,
  p_description_fr text,
  p_description_ar text,
  p_credit_cost bigint,
  p_reference_value_minor bigint,
  p_internal_cost_minor bigint,
  p_currency text,
  p_library_id uuid,
  p_service_id uuid,
  p_quota bigint,
  p_capacity_rule jsonb,
  p_eligibility_rule jsonb,
  p_cancellation_rule_version text,
  p_effective_from timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  def uuid;
  ver integer;
  hid text;
  cached jsonb;
  result jsonb;
  vid uuid;
begin
  if a is null or not private.credits_admin_access(a) then
    raise exception 'BENEFIT_WRITE_DENIED' using errcode = '42501';
  end if;
  if p_code !~ '^[A-Z][A-Z0-9_]{2,79}$'
     or p_benefit_type not in ('PLATFORM_FEATURE', 'SERVICE_UNIT', 'CREDIT_SERVICE', 'PRIORITY', 'QUOTA', 'ACCESS_RIGHT', 'SERVICE_SUBSIDY', 'CONSULTATION', 'REPORT', 'CUSTOM')
     or p_fulfillment_mode not in ('AUTOMATED_PLATFORM', 'MATRICIA_INTERNAL', 'DIRECT_PROVIDER', 'SUBCONTRACTOR_POOL', 'VOLUME_POOL', 'RFQ')
     or length(btrim(coalesce(p_name_fr, ''))) not between 2 and 200
     or length(btrim(coalesce(p_name_ar, ''))) not between 2 and 200
     or length(btrim(coalesce(p_description_fr, ''))) not between 3 and 2000
     or length(btrim(coalesce(p_description_ar, ''))) not between 3 and 2000
     or p_credit_cost < 0 or p_reference_value_minor < 0 or p_internal_cost_minor < 0
     or p_currency !~ '^[A-Z]{3}$'
     or (p_quota is not null and p_quota <= 0)
     or jsonb_typeof(coalesce(p_capacity_rule, '{}'::jsonb)) <> 'object'
     or jsonb_typeof(coalesce(p_eligibility_rule, '{}'::jsonb)) <> 'object'
     or length(btrim(coalesce(p_cancellation_rule_version, ''))) not between 1 and 80
     or p_effective_from is null
     or (p_service_id is not null and p_library_id is null)
     or not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE') then
    raise exception 'INVALID_BENEFIT_VERSION' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object(
    'code', p_code, 'type', p_benefit_type, 'mode', p_fulfillment_mode,
    'name_fr', p_name_fr, 'name_ar', p_name_ar, 'description_fr', p_description_fr, 'description_ar', p_description_ar,
    'credit_cost', p_credit_cost, 'reference', p_reference_value_minor, 'internal', p_internal_cost_minor,
    'currency', p_currency, 'library', p_library_id, 'service', p_service_id, 'quota', p_quota,
    'capacity', coalesce(p_capacity_rule, '{}'::jsonb), 'eligibility', coalesce(p_eligibility_rule, '{}'::jsonb),
    'cancel', p_cancellation_rule_version, 'from', p_effective_from
  ));
  cached := private.begin_credit_command(p_audit_organization_id, 'admin.benefit.version.create', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  insert into public.benefit_definitions(code, status, created_by)
  values (p_code, 'DRAFT', a)
  on conflict (code) do nothing;
  select id into def from public.benefit_definitions where code = p_code;
  select coalesce(max(version), 0) + 1 into ver from public.benefit_versions where benefit_id = def;
  insert into public.benefit_versions(
    benefit_id, version, status, benefit_type, fulfillment_mode, name_fr, name_ar, description_fr, description_ar,
    credit_cost, reference_value_minor, internal_cost_minor, currency, library_id, service_id, quota,
    capacity_rule, eligibility_rule, cancellation_rule_version, effective_from, content_hash, created_by
  ) values (
    def, ver, 'DRAFT', p_benefit_type, p_fulfillment_mode, p_name_fr, p_name_ar, p_description_fr, p_description_ar,
    p_credit_cost, p_reference_value_minor, p_internal_cost_minor, p_currency, p_library_id, p_service_id, p_quota,
    coalesce(p_capacity_rule, '{}'::jsonb), coalesce(p_eligibility_rule, '{}'::jsonb), p_cancellation_rule_version,
    p_effective_from, hid, a
  ) returning id into vid;
  result := jsonb_build_object('outcome', 'BENEFIT_VERSION_CREATED', 'benefit_id', def, 'benefit_version_id', vid, 'version', ver, 'status', 'DRAFT');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.benefit.version_created', 'benefit_version', vid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'benefit_version', vid::text, 'BenefitVersionCreatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'admin.benefit.version.create', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.activate_benefit_version(
  p_audit_organization_id uuid,
  p_benefit_version_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  v public.benefit_versions%rowtype;
  hid text;
  cached jsonb;
  result jsonb;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'BENEFIT_ACTIVATE_DENIED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE') then
    raise exception 'INVALID_BENEFIT_ACTIVATION' using errcode = '22023';
  end if;
  select * into v from public.benefit_versions where id = p_benefit_version_id;
  if not found or v.status not in ('DRAFT', 'UNDER_REVIEW') then
    raise exception 'BENEFIT_VERSION_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('benefit_version', v.id));
  cached := private.begin_credit_command(p_audit_organization_id, 'admin.benefit.version.activate.' || v.id::text, p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  update public.benefit_versions
     set status = 'RETIRED', effective_to = coalesce(effective_to, clock_timestamp())
   where benefit_id = v.benefit_id and status = 'ACTIVE' and id <> v.id;
  update public.benefit_versions set status = 'ACTIVE' where id = v.id;
  update public.benefit_definitions set status = 'ACTIVE' where id = v.benefit_id;
  result := jsonb_build_object('outcome', 'BENEFIT_VERSION_ACTIVATED', 'benefit_version_id', v.id, 'benefit_id', v.benefit_id, 'version', v.version);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.benefit.version_activated', 'benefit_version', v.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'benefit_version', v.id::text, 'BenefitVersionActivatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'admin.benefit.version.activate.' || v.id::text, p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.create_box_version(
  p_audit_organization_id uuid,
  p_code text,
  p_box_type text,
  p_name_fr text,
  p_name_ar text,
  p_credit_budget bigint,
  p_rollover_months integer,
  p_rules_snapshot jsonb,
  p_cost_low_minor bigint,
  p_cost_expected_minor bigint,
  p_cost_full_minor bigint,
  p_currency text,
  p_effective_from timestamptz,
  p_slots jsonb,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  def uuid;
  ver integer;
  hid text;
  cached jsonb;
  result jsonb;
  vid uuid;
  slot jsonb;
begin
  if a is null or not private.credits_admin_access(a) then
    raise exception 'BOX_WRITE_DENIED' using errcode = '42501';
  end if;
  if p_code !~ '^[A-Z][A-Z0-9_]{2,79}$'
     or p_box_type not in ('FIXED', 'SEMI_CUSTOM', 'CUSTOM', 'ENTERPRISE', 'MULTI_USER', 'MULTI_LIBRARY')
     or length(btrim(coalesce(p_name_fr, ''))) not between 2 and 200
     or length(btrim(coalesce(p_name_ar, ''))) not between 2 and 200
     or p_credit_budget < 0 or p_rollover_months < 0
     or jsonb_typeof(coalesce(p_rules_snapshot, '{}'::jsonb)) <> 'object'
     or p_cost_low_minor < 0 or p_cost_expected_minor < 0 or p_cost_full_minor < 0
     or p_currency !~ '^[A-Z]{3}$'
     or p_effective_from is null
     or jsonb_typeof(coalesce(p_slots, '[]'::jsonb)) <> 'array'
     or not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE') then
    raise exception 'INVALID_BOX_VERSION' using errcode = '22023';
  end if;
  for slot in select value from jsonb_array_elements(coalesce(p_slots, '[]'::jsonb))
  loop
    if jsonb_typeof(slot) <> 'object'
       or coalesce(slot->>'slot_code', '') !~ '^[A-Z][A-Z0-9_]{1,39}$'
       or coalesce(slot->>'slot_kind', '') not in ('MANDATORY', 'OPTIONAL')
       or coalesce((slot->>'minimum_selections')::integer, -1) < 0
       or coalesce((slot->>'maximum_selections')::integer, -1) < coalesce((slot->>'minimum_selections')::integer, 0)
       or jsonb_typeof(coalesce(slot->'allowed_benefit_version_ids', '[]'::jsonb)) <> 'array' then
      raise exception 'INVALID_BOX_SLOT' using errcode = '22023';
    end if;
  end loop;
  hid := private.canonical_request_hash(jsonb_build_object(
    'code', p_code, 'type', p_box_type, 'name_fr', p_name_fr, 'name_ar', p_name_ar,
    'budget', p_credit_budget, 'rollover', p_rollover_months, 'rules', coalesce(p_rules_snapshot, '{}'::jsonb),
    'cost_low', p_cost_low_minor, 'cost_expected', p_cost_expected_minor, 'cost_full', p_cost_full_minor,
    'currency', p_currency, 'from', p_effective_from, 'slots', coalesce(p_slots, '[]'::jsonb)
  ));
  cached := private.begin_credit_command(p_audit_organization_id, 'admin.box.version.create', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  insert into public.box_definitions(code, status, created_by)
  values (p_code, 'DRAFT', a)
  on conflict (code) do nothing;
  select id into def from public.box_definitions where code = p_code;
  select coalesce(max(version), 0) + 1 into ver from public.box_versions where box_id = def;
  insert into public.box_versions(
    box_id, version, status, box_type, name_fr, name_ar, credit_budget, rollover_months, rules_snapshot,
    cost_low_minor, cost_expected_minor, cost_full_minor, currency, content_hash, effective_from, created_by
  ) values (
    def, ver, 'DRAFT', p_box_type, p_name_fr, p_name_ar, p_credit_budget, p_rollover_months, coalesce(p_rules_snapshot, '{}'::jsonb),
    p_cost_low_minor, p_cost_expected_minor, p_cost_full_minor, p_currency, hid, p_effective_from, a
  ) returning id into vid;
  insert into public.box_slots(box_version_id, slot_code, slot_kind, minimum_selections, maximum_selections, allowed_benefit_version_ids)
  select vid,
         slot->>'slot_code',
         slot->>'slot_kind',
         coalesce((slot->>'minimum_selections')::integer, 0),
         (slot->>'maximum_selections')::integer,
         coalesce((
           select array_agg((value #>> '{}')::uuid)
           from jsonb_array_elements(coalesce(slot->'allowed_benefit_version_ids', '[]'::jsonb))
         ), '{}'::uuid[])
  from jsonb_array_elements(coalesce(p_slots, '[]'::jsonb)) as slot;
  result := jsonb_build_object('outcome', 'BOX_VERSION_CREATED', 'box_id', def, 'box_version_id', vid, 'version', ver, 'status', 'DRAFT');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.box.version_created', 'box_version', vid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'box_version', vid::text, 'BoxVersionCreatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'admin.box.version.create', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.activate_box_version(
  p_audit_organization_id uuid,
  p_box_version_id uuid,
  p_approval_reference text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  v public.box_versions%rowtype;
  hid text;
  cached jsonb;
  result jsonb;
  approval text;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'BOX_ACTIVATE_DENIED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE') then
    raise exception 'INVALID_BOX_ACTIVATION' using errcode = '22023';
  end if;
  select * into v from public.box_versions where id = p_box_version_id;
  if not found or v.status not in ('DRAFT', 'UNDER_REVIEW') then
    raise exception 'BOX_VERSION_NOT_ACTIVATABLE' using errcode = '55000';
  end if;
  approval := nullif(btrim(coalesce(p_approval_reference, v.approval_reference, '')), '');
  if v.cost_full_minor > v.cost_expected_minor and length(coalesce(approval, '')) < 3 then
    raise exception 'BOX_COST_APPROVAL_REQUIRED' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('box_version', v.id, 'approval', approval));
  cached := private.begin_credit_command(p_audit_organization_id, 'admin.box.version.activate.' || v.id::text, p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  update public.box_versions
     set status = 'RETIRED', effective_to = coalesce(effective_to, clock_timestamp())
   where box_id = v.box_id and status = 'ACTIVE' and id <> v.id;
  update public.box_versions
     set status = 'ACTIVE', approval_reference = approval
   where id = v.id;
  update public.box_definitions set status = 'ACTIVE' where id = v.box_id;
  result := jsonb_build_object('outcome', 'BOX_VERSION_ACTIVATED', 'box_version_id', v.id, 'box_id', v.box_id, 'version', v.version, 'approval_reference', approval);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.box.version_activated', 'box_version', v.id::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'box_version', v.id::text, 'BoxVersionActivatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'admin.box.version.activate.' || v.id::text, p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.link_plan_box_rule(
  p_audit_organization_id uuid,
  p_plan_version_id uuid,
  p_box_version_id uuid,
  p_rule_snapshot jsonb,
  p_effective_from timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  hid text;
  cached jsonb;
  result jsonb;
  rid uuid;
begin
  if a is null or not private.credits_admin_access(a) or auth.jwt()->>'aal' is distinct from 'aal2' then
    raise exception 'PLAN_BOX_LINK_DENIED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_audit_organization_id and status = 'ACTIVE')
     or not exists (select 1 from public.subscription_plan_versions where id = p_plan_version_id and status = 'ACTIVE')
     or not exists (select 1 from public.box_versions where id = p_box_version_id and status = 'ACTIVE')
     or jsonb_typeof(coalesce(p_rule_snapshot, '{}'::jsonb)) <> 'object'
     or p_effective_from is null then
    raise exception 'INVALID_PLAN_BOX_RULE' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object('plan', p_plan_version_id, 'box', p_box_version_id, 'rule', coalesce(p_rule_snapshot, '{}'::jsonb), 'from', p_effective_from));
  cached := private.begin_credit_command(p_audit_organization_id, 'admin.plan.box.link', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  insert into public.plan_box_rules(plan_version_id, box_version_id, status, effective_from, rule_snapshot)
  values (p_plan_version_id, p_box_version_id, 'ACTIVE', p_effective_from, coalesce(p_rule_snapshot, '{}'::jsonb))
  returning id into rid;
  result := jsonb_build_object('outcome', 'PLAN_BOX_RULE_LINKED', 'plan_box_rule_id', rid, 'plan_version_id', p_plan_version_id, 'box_version_id', p_box_version_id);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_audit_organization_id, a, 'USER', 'admin.plan_box.linked', 'plan_box_rule', rid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_audit_organization_id, 'plan_box_rule', rid::text, 'PlanBoxRuleLinkedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_credit_command(p_audit_organization_id, 'admin.plan.box.link', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.list_admin_boxes_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 100), 200));
begin
  if actor is null or not (private.credits_admin_access(actor) or private.has_platform_role(array['READ_ONLY_AUDITOR'], actor)) then
    raise exception 'ADMIN_BOXES_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_write', private.credits_admin_access(actor),
      'can_activate', private.credits_admin_access(actor)
    ),
    'benefits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'benefit_id', d.id, 'code', d.code, 'version', v.version, 'status', v.status,
        'benefit_type', v.benefit_type, 'fulfillment_mode', v.fulfillment_mode,
        'name_fr', v.name_fr, 'name_ar', v.name_ar, 'credit_cost', v.credit_cost::text,
        'reference_value_minor', v.reference_value_minor::text, 'internal_cost_minor', v.internal_cost_minor::text,
        'currency', v.currency, 'effective_from', v.effective_from
      ) order by d.code, v.version desc)
      from (
        select * from public.benefit_versions order by created_at desc limit lim
      ) v
      join public.benefit_definitions d on d.id = v.benefit_id
    ), '[]'::jsonb),
    'boxes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'box_id', d.id, 'code', d.code, 'version', v.version, 'status', v.status,
        'box_type', v.box_type, 'name_fr', v.name_fr, 'name_ar', v.name_ar,
        'credit_budget', v.credit_budget::text, 'cost_low_minor', v.cost_low_minor::text,
        'cost_expected_minor', v.cost_expected_minor::text, 'cost_full_minor', v.cost_full_minor::text,
        'currency', v.currency, 'approval_reference', v.approval_reference, 'effective_from', v.effective_from,
        'needs_approval', (v.cost_full_minor > v.cost_expected_minor and v.approval_reference is null),
        'slots', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', s.id, 'slot_code', s.slot_code, 'slot_kind', s.slot_kind,
            'minimum_selections', s.minimum_selections, 'maximum_selections', s.maximum_selections
          ) order by s.slot_code)
          from public.box_slots s where s.box_version_id = v.id
        ), '[]'::jsonb)
      ) order by d.code, v.version desc)
      from (
        select * from public.box_versions order by created_at desc limit lim
      ) v
      join public.box_definitions d on d.id = v.box_id
    ), '[]'::jsonb),
    'plan_matrix', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'plan_code', p.code, 'plan_version', pv.version, 'box_code', d.code,
        'box_version', bv.version, 'status', r.status, 'effective_from', r.effective_from
      ) order by p.code, pv.version, d.code)
      from public.plan_box_rules r
      join public.box_versions bv on bv.id = r.box_version_id
      join public.box_definitions d on d.id = bv.box_id
      join public.subscription_plan_versions pv on pv.id = r.plan_version_id
      join public.subscription_plans p on p.id = pv.plan_id
      where r.status = 'ACTIVE'
      limit lim
    ), '[]'::jsonb),
    'plans', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pv.id, 'plan_code', p.code, 'version', pv.version, 'status', pv.status,
        'currency', pv.currency, 'monthly_price_minor', pv.monthly_price_minor::text,
        'monthly_credit_grant', pv.monthly_credit_grant::text
      ) order by p.code)
      from public.subscription_plan_versions pv
      join public.subscription_plans p on p.id = pv.plan_id
      where pv.status = 'ACTIVE'
    ), '[]'::jsonb),
    'wallets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'wallet_id', w.id, 'organization_id', w.organization_id, 'organization_name', o.display_name,
        'wallet_type', w.wallet_type, 'balance', coalesce(b.balance, 0)::text
      ) order by o.display_name)
      from public.credit_wallets w
      join public.organizations o on o.id = w.organization_id
      left join public.credit_wallet_balances b on b.wallet_id = w.id
      where w.wallet_type = 'CLIENT'
      limit lim
    ), '[]'::jsonb),
    'lots', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'organization_id', l.organization_id, 'source_type', l.source_type,
        'quantity', l.quantity::text, 'expires_at', l.expires_at, 'revenue_value_minor', l.revenue_value_minor::text
      ) order by l.created_at desc)
      from (
        select * from public.credit_lots order by created_at desc limit lim
      ) l
    ), '[]'::jsonb),
    'redemptions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'organization_id', r.organization_id, 'status', r.status,
        'units', r.units::text, 'reserved_credits', r.reserved_credits::text, 'created_at', r.created_at
      ) order by r.created_at desc)
      from (
        select * from public.benefit_redemptions order by created_at desc limit lim
      ) r
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.list_admin_pnl_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 100), 200));
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR'], actor) then
    raise exception 'ADMIN_PNL_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_close', private.has_platform_role(array['SUPER_ADMIN', 'FINANCE_MANAGER'], actor)
    ),
    'rules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'franchise_type', r.franchise_type, 'version', r.version,
        'franchisee_share_bps', r.franchisee_share_bps, 'neoxa_share_bps', r.neoxa_share_bps,
        'asma_share_bps', r.asma_matricia_share_bps, 'effective_from', r.effective_from
      ) order by r.franchise_type, r.version desc)
      from public.franchise_finance_rule_versions r
      where r.status = 'ACTIVE'
    ), '[]'::jsonb),
    'books', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id, 'library_id', b.library_id, 'library_code', l.code,
        'franchise_organization_id', b.franchise_organization_id, 'organization_name', o.display_name,
        'franchise_type', b.franchise_type, 'operator_code', b.operator_code, 'currency', b.currency,
        'status', b.status, 'rule_version_id', b.opened_under_rule_version_id,
        'latest_closure', (
          select jsonb_build_object(
            'id', c.id, 'period_start', c.period_start, 'period_end', c.period_end, 'version', c.version,
            'gross_revenue_ex_tax_minor', c.gross_revenue_ex_tax_minor::text,
            'costs_and_refunds_minor', c.costs_and_refunds_minor::text,
            'distributable_profit_minor', c.distributable_profit_minor::text, 'closed_at', c.closed_at
          )
          from public.franchise_profit_closure_versions c
          where c.book_id = b.id
          order by c.closed_at desc
          limit 1
        ),
        'allocations', coalesce((
          select jsonb_agg(jsonb_build_object(
            'beneficiary_code', a.beneficiary_code, 'share_bps', a.share_bps, 'amount_minor', a.amount_minor::text
          ) order by a.beneficiary_code)
          from public.franchise_profit_allocations a
          join public.franchise_profit_closure_versions c on c.id = a.closure_version_id
          where c.book_id = b.id
            and c.id = (select id from public.franchise_profit_closure_versions x where x.book_id = b.id order by x.closed_at desc limit 1)
        ), '[]'::jsonb)
      ) order by l.code, b.franchise_type)
      from public.franchise_pnl_books b
      join public.catalog_libraries l on l.id = b.library_id
      join public.organizations o on o.id = b.franchise_organization_id
      limit lim
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.list_admin_provider_closure_dashboard(p_limit integer default 100)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 100), 200));
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER', 'READ_ONLY_AUDITOR'], actor) then
    raise exception 'ADMIN_CLOSURE_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_issue_statement', private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'FINANCE_MANAGER'], actor)
    ),
    'unstatemented', coalesce((
      select jsonb_agg(jsonb_build_object(
        'provider_organization_id', x.provider_organization_id,
        'organization_name', o.display_name,
        'currency', x.currency,
        'event_count', x.event_count,
        'subtotal_minor', x.subtotal_minor::text,
        'tax_minor', x.tax_minor::text,
        'total_minor', (x.subtotal_minor + x.tax_minor)::text
      ) order by o.display_name)
      from (
        select e.provider_organization_id, e.currency, count(*)::integer as event_count,
               coalesce(sum(e.commission_amount_minor), 0)::bigint as subtotal_minor,
               coalesce(sum(e.tax_amount_minor), 0)::bigint as tax_minor
        from public.provider_payable_events e
        where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
        group by e.provider_organization_id, e.currency
        having coalesce(sum(e.commission_amount_minor), 0) + coalesce(sum(e.tax_amount_minor), 0) > 0
        limit lim
      ) x
      join public.organizations o on o.id = x.provider_organization_id
    ), '[]'::jsonb),
    'statements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'provider_organization_id', s.provider_organization_id, 'organization_name', o.display_name,
        'statement_number', s.statement_number, 'period_start', s.period_start, 'period_end', s.period_end,
        'currency', s.currency, 'total_minor', s.total_minor::text, 'invoiced', exists(select 1 from public.provider_invoices i where i.statement_id = s.id)
      ) order by s.issued_at desc)
      from (
        select * from public.provider_statements order by issued_at desc limit lim
      ) s
      join public.organizations o on o.id = s.provider_organization_id
    ), '[]'::jsonb),
    'overdue_invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'provider_organization_id', i.provider_organization_id, 'organization_name', o.display_name,
        'invoice_number', i.invoice_number, 'due_on', i.due_on, 'currency', i.currency,
        'outstanding_minor', (i.total_minor - coalesce(p.paid_minor, 0))::text
      ) order by i.due_on)
      from public.provider_invoices i
      join public.organizations o on o.id = i.provider_organization_id
      left join (
        select invoice_id, sum(amount_minor)::bigint as paid_minor
        from public.provider_payment_allocations
        group by invoice_id
      ) p on p.invoice_id = i.id
      where i.due_on < current_date and i.total_minor - coalesce(p.paid_minor, 0) > 0
      limit lim
    ), '[]'::jsonb)
  );
end
$$;

create or replace function public.sweep_admin_exceptions()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  actor uuid := auth.uid();
  rec record;
  opened integer := 0;
  skipped integer := 0;
  due timestamptz := clock_timestamp() + interval '4 hours';
  key text;
  existing uuid;
begin
  if actor is null or not private.has_platform_role(array['SUPER_ADMIN', 'MATRICIA_ADMIN', 'COMPLIANCE_MANAGER', 'SUPPORT_AGENT'], actor) then
    raise exception 'ADMIN_SWEEP_DENIED' using errcode = '42501';
  end if;

  for rec in
    select 'FINANCE'::text as source_kind, 'BILLING_EXCEPTION'::text as resource_type, i.id::text as resource_id,
           i.provider_organization_id as organization_id, 'HIGH'::text as priority,
           'Facture prestataire échue'::text as title_fr, 'فاتورة مقدم خدمة متأخرة'::text as title_ar,
           jsonb_build_object('kind', 'OVERDUE_INVOICE', 'due_on', i.due_on) as context
    from public.provider_invoices i
    left join (
      select invoice_id, sum(amount_minor)::bigint as paid_minor
      from public.provider_payment_allocations
      group by invoice_id
    ) p on p.invoice_id = i.id
    where i.due_on < current_date and i.total_minor - coalesce(p.paid_minor, 0) > 0
    union all
    select 'FINANCE', 'UNSTATMENTED_PAYABLE', e.id::text, e.provider_organization_id, 'MEDIUM',
           'Événement payable non relevé', 'حدث مستحق غير مدرج في كشف',
           jsonb_build_object('kind', 'UNSTATMENTED_PAYABLE', 'occurred_on', e.occurred_on)
    from public.provider_payable_events e
    where not exists (select 1 from public.provider_statement_lines l where l.payable_event_id = e.id)
    union all
    select 'EXCEPTION', 'MATCHING_RUN', m.id::text, r.client_organization_id,
           case when m.status = 'FAILED' then 'HIGH' else 'MEDIUM' end,
           'Matching sans candidat ou en échec', 'مطابقة دون مرشح أو فاشلة',
           jsonb_build_object('kind', 'MATCHING_EXCEPTION', 'status', m.status)
    from public.matching_runs m
    join public.service_requests r on r.id = m.request_id
    where m.status in ('FAILED', 'NO_CANDIDATE')
    union all
    select 'POOL', 'INVENTORY_POOL', p.id::text, p.owner_organization_id, 'MEDIUM',
           'Pool volume en stock faible', 'مجمع حجم بمخزون منخفض',
           jsonb_build_object('kind', 'LOW_STOCK', 'status', p.status)
    from public.service_inventory_pools p
    where p.status = 'LOW_STOCK'
    union all
    select 'FINANCE', 'SUBSCRIPTION', s.id::text, s.organization_id, 'HIGH',
           'Abonnement échu', 'اشتراك متأخر',
           jsonb_build_object('kind', 'PAST_DUE_SUBSCRIPTION', 'status', s.status)
    from public.subscriptions s
    where s.status = 'PAST_DUE'
  loop
    select w.id into existing
    from public.admin_work_items w
    join public.admin_queue_versions q on q.id = w.queue_version_id
    where q.queue_key = 'EXCEPTIONS' and q.status = 'ACTIVE'
      and w.source_kind = rec.source_kind
      and w.resource_type = rec.resource_type
      and w.resource_id = rec.resource_id;
    if existing is not null then
      skipped := skipped + 1;
      continue;
    end if;
    key := left('sweep:' || rec.resource_type || ':' || rec.resource_id, 200);
    begin
      perform public.open_admin_work_item(
        'EXCEPTIONS', rec.organization_id, rec.source_kind, rec.resource_type, rec.resource_id,
        rec.title_fr, rec.title_ar, rec.priority, due, rec.context, rec.title_fr, key, extensions.gen_random_uuid()
      );
      opened := opened + 1;
    exception
      when unique_violation then
        skipped := skipped + 1;
    end;
  end loop;

  return jsonb_build_object('outcome', 'ADMIN_EXCEPTIONS_SWEPT', 'opened', opened, 'skipped', skipped);
end
$$;

create or replace function public.create_framework_agreement_draft(
  p_owner_organization_id uuid,
  p_sku_id uuid,
  p_agreement_code text,
  p_valid_from date,
  p_valid_to date,
  p_forecast_units numeric,
  p_minimum_commitment_units numeric,
  p_maximum_units numeric,
  p_payment_model text,
  p_currency text,
  p_price_tiers jsonb,
  p_rebate_rules jsonb,
  p_sla_snapshot jsonb,
  p_penalty_rules jsonb,
  p_exit_rules jsonb,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  a uuid := auth.uid();
  hid text;
  cached jsonb;
  result jsonb;
  aid uuid;
  vid uuid;
begin
  if a is null or not private.volume_admin_access(a) then
    raise exception 'FRAMEWORK_DRAFT_DENIED' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_owner_organization_id and status = 'ACTIVE')
     or not exists (select 1 from public.service_skus where id = p_sku_id and status = 'ACTIVE')
     or length(btrim(coalesce(p_agreement_code, ''))) not between 3 and 80
     or p_valid_to < p_valid_from
     or p_forecast_units is null or p_forecast_units <= 0
     or p_minimum_commitment_units is null or p_minimum_commitment_units < 0
     or p_maximum_units is null or p_maximum_units <= 0
     or p_minimum_commitment_units > p_maximum_units
     or p_forecast_units > p_maximum_units
     or p_payment_model not in ('PAY_PER_USE', 'PREPAID', 'HYBRID')
     or p_currency !~ '^[A-Z]{3}$'
     or jsonb_typeof(coalesce(p_price_tiers, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_price_tiers, '[]'::jsonb)) < 1
     or jsonb_typeof(coalesce(p_rebate_rules, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_sla_snapshot, '{}'::jsonb)) <> 'object'
     or jsonb_typeof(coalesce(p_penalty_rules, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_exit_rules, '{}'::jsonb)) <> 'object' then
    raise exception 'INVALID_FRAMEWORK_DRAFT' using errcode = '22023';
  end if;
  hid := private.canonical_request_hash(jsonb_build_object(
    'owner', p_owner_organization_id, 'sku', p_sku_id, 'code', p_agreement_code,
    'from', p_valid_from, 'to', p_valid_to, 'forecast', p_forecast_units,
    'min', p_minimum_commitment_units, 'max', p_maximum_units, 'model', p_payment_model,
    'currency', p_currency, 'tiers', p_price_tiers, 'rebates', coalesce(p_rebate_rules, '[]'::jsonb),
    'sla', coalesce(p_sla_snapshot, '{}'::jsonb), 'penalties', coalesce(p_penalty_rules, '[]'::jsonb),
    'exit', coalesce(p_exit_rules, '{}'::jsonb)
  ));
  cached := private.begin_volume_command(p_owner_organization_id, 'volume.framework.draft', p_idempotency_key, hid, a);
  if cached is not null then return cached; end if;
  insert into public.framework_agreements(owner_organization_id, sku_id, agreement_code, status, current_version, created_by)
  values (p_owner_organization_id, p_sku_id, p_agreement_code, 'DRAFT', 1, a)
  returning id into aid;
  insert into public.framework_agreement_versions(
    agreement_id, version, valid_from, valid_to, forecast_units, minimum_commitment_units, maximum_units,
    payment_model, currency, price_tiers, rebate_rules, sla_snapshot, penalty_rules, exit_rules, content_hash, created_by
  ) values (
    aid, 1, p_valid_from, p_valid_to, p_forecast_units, p_minimum_commitment_units, p_maximum_units,
    p_payment_model, p_currency, p_price_tiers, coalesce(p_rebate_rules, '[]'::jsonb),
    coalesce(p_sla_snapshot, '{}'::jsonb), coalesce(p_penalty_rules, '[]'::jsonb),
    coalesce(p_exit_rules, '{}'::jsonb), hid, a
  ) returning id into vid;
  result := jsonb_build_object('outcome', 'FRAMEWORK_DRAFT_CREATED', 'agreement_id', aid, 'agreement_version_id', vid, 'status', 'DRAFT');
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (p_owner_organization_id, a, 'USER', 'admin.framework.draft_created', 'framework_agreement', aid::text, p_correlation_id, result, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (p_owner_organization_id, 'framework_agreement', aid::text, 'FrameworkDraftCreatedV1', p_correlation_id, result, p_idempotency_key);
  perform private.finish_volume_command(p_owner_organization_id, 'volume.framework.draft', p_idempotency_key, result);
  return result;
end
$$;

create or replace function public.get_admin_volume_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null or not private.volume_admin_access(actor) then
    raise exception 'ADMIN_VOLUME_DASHBOARD_DENIED' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'generated_at', clock_timestamp(),
    'capabilities', jsonb_build_object(
      'can_allocate', true,
      'can_consume', true,
      'can_negotiate', true
    ),
    'summary', jsonb_build_object(
      'pool_count', (select count(*) from public.service_inventory_pools),
      'active_pool_count', (select count(*) from public.service_inventory_pools where status in ('ACTIVE', 'LOW_STOCK')),
      'low_stock_count', (select count(*) from public.service_inventory_pools where status = 'LOW_STOCK'),
      'open_reservation_count', (select count(*) from public.service_reservations where status in ('RESERVED', 'COMMITTED', 'PARTIALLY_CONSUMED')),
      'client_count', (select count(distinct client_organization_id) from public.service_reservations),
      'provider_count', (select count(distinct provider_organization_id) from public.provider_capacity_commitments where status = 'ACTIVE'),
      'draft_agreement_count', (select count(*) from public.framework_agreements where status = 'DRAFT')
    ),
    'pools', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'agreement_id', p.agreement_id,
        'agreement_version_id', p.agreement_version_id,
        'agreement_code', a.agreement_code,
        'sku_code', s.code,
        'unit_code', s.unit_code,
        'currency', av.currency,
        'contracted_units', p.contracted_units::text,
        'available_units', p.available_units::text,
        'reserved_units', p.reserved_units::text,
        'committed_units', p.committed_units::text,
        'consumed_units', p.consumed_units::text,
        'released_units', p.released_units::text,
        'status', p.status,
        'window_end', p.window_end,
        'row_version', p.row_version::text,
        'reservation_count', (select count(*) from public.service_reservations r where r.pool_id = p.id),
        'client_count', (select count(distinct r.client_organization_id) from public.service_reservations r where r.pool_id = p.id)
      ) order by p.window_end, p.id)
      from public.service_inventory_pools p
      join public.framework_agreements a on a.id = p.agreement_id
      join public.framework_agreement_versions av on av.id = p.agreement_version_id
      join public.service_skus s on s.id = a.sku_id
    ), '[]'::jsonb),
    'reservations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'pool_id', r.pool_id,
        'reserved_units', r.reserved_units::text,
        'consumed_units', r.consumed_units::text,
        'released_units', r.released_units::text,
        'status', r.status,
        'expires_at', r.expires_at,
        'allocated_units', coalesce((select sum(x.allocated_units) from public.service_provider_allocations x where x.reservation_id = r.id), 0)::text
      ) order by r.expires_at, r.id)
      from public.service_reservations r
      where r.status in ('RESERVED', 'COMMITTED', 'PARTIALLY_CONSUMED')
    ), '[]'::jsonb),
    'commitments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'agreement_version_id', c.agreement_version_id,
        'capacity_units', c.capacity_units::text,
        'remaining_units', (c.capacity_units - c.committed_units - c.consumed_units - c.released_units)::text,
        'allocation_share_basis_points', c.allocation_share_basis_points,
        'quality_score_basis_points', c.quality_score_basis_points,
        'unit_price_minor', c.unit_price_minor::text,
        'currency', av.currency,
        'status', c.status
      ) order by c.agreement_version_id, c.quality_score_basis_points desc, c.id)
      from public.provider_capacity_commitments c
      join public.framework_agreement_versions av on av.id = c.agreement_version_id
      where c.status = 'ACTIVE'
        and c.capacity_units - c.committed_units - c.consumed_units - c.released_units > 0
    ), '[]'::jsonb),
    'allocations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', x.id,
        'reservation_id', x.reservation_id,
        'provider_commitment_id', x.provider_commitment_id,
        'allocated_units', x.allocated_units::text,
        'consumed_units', coalesce((select sum(c.consumed_units) from public.service_provider_consumptions c where c.allocation_id = x.id), 0)::text,
        'unit_price_minor', x.unit_price_minor::text,
        'currency', x.currency,
        'allocated_at', x.allocated_at
      ) order by x.allocated_at desc, x.id)
      from public.service_provider_allocations x
      join public.service_reservations r on r.id = x.reservation_id
      where r.status in ('COMMITTED', 'PARTIALLY_CONSUMED')
    ), '[]'::jsonb),
    'agreements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'agreement_code', a.agreement_code, 'status', a.status, 'sku_code', s.code,
        'currency', av.currency, 'valid_from', av.valid_from, 'valid_to', av.valid_to,
        'forecast_units', av.forecast_units::text, 'payment_model', av.payment_model,
        'owner_organization_id', a.owner_organization_id
      ) order by a.created_at desc)
      from public.framework_agreements a
      join public.service_skus s on s.id = a.sku_id
      left join lateral (
        select * from public.framework_agreement_versions v where v.agreement_id = a.id order by v.version desc limit 1
      ) av on true
    ), '[]'::jsonb),
    'skus', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'code', s.code, 'unit_code', s.unit_code, 'currency', s.currency,
        'reference_cost_minor', s.reference_cost_minor::text
      ) order by s.code)
      from public.service_skus s
      where s.status = 'ACTIVE'
    ), '[]'::jsonb),
    'profitability', coalesce((
      select jsonb_agg(jsonb_build_object(
        'agreement_code', a.agreement_code, 'sku_code', s.code, 'currency', av.currency,
        'consumed_units', p.consumed_units::text,
        'consumed_cost_minor', coalesce((
          select sum(c.total_cost_minor) from public.service_provider_consumptions c
          join public.service_reservations r on r.id = c.reservation_id
          where r.pool_id = p.id
        ), 0)::text,
        'reference_cost_minor', s.reference_cost_minor::text
      ) order by a.agreement_code)
      from public.service_inventory_pools p
      join public.framework_agreements a on a.id = p.agreement_id
      join public.framework_agreement_versions av on av.id = p.agreement_version_id
      join public.service_skus s on s.id = a.sku_id
    ), '[]'::jsonb)
  ) into result;

  return result;
end
$$;

revoke all on function private.guard_offer_version_mutation() from public, anon, authenticated, service_role;
revoke all on function public.create_benefit_version(uuid, text, text, text, text, text, text, text, bigint, bigint, bigint, text, uuid, uuid, bigint, jsonb, jsonb, text, timestamptz, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.activate_benefit_version(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.create_box_version(uuid, text, text, text, text, bigint, integer, jsonb, bigint, bigint, bigint, text, timestamptz, jsonb, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.activate_box_version(uuid, uuid, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.link_plan_box_rule(uuid, uuid, uuid, jsonb, timestamptz, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_boxes_dashboard(integer) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_pnl_dashboard(integer) from public, anon, authenticated, service_role;
revoke all on function public.list_admin_provider_closure_dashboard(integer) from public, anon, authenticated, service_role;
revoke all on function public.sweep_admin_exceptions() from public, anon, authenticated, service_role;
revoke all on function public.create_framework_agreement_draft(uuid, uuid, text, date, date, numeric, numeric, numeric, text, text, jsonb, jsonb, jsonb, jsonb, jsonb, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.get_admin_volume_dashboard() from public, anon, authenticated, service_role;

grant execute on function public.create_benefit_version(uuid, text, text, text, text, text, text, text, bigint, bigint, bigint, text, uuid, uuid, bigint, jsonb, jsonb, text, timestamptz, text, uuid) to authenticated;
grant execute on function public.activate_benefit_version(uuid, uuid, text, uuid) to authenticated;
grant execute on function public.create_box_version(uuid, text, text, text, text, bigint, integer, jsonb, bigint, bigint, bigint, text, timestamptz, jsonb, text, uuid) to authenticated;
grant execute on function public.activate_box_version(uuid, uuid, text, text, uuid) to authenticated;
grant execute on function public.link_plan_box_rule(uuid, uuid, uuid, jsonb, timestamptz, text, uuid) to authenticated;
grant execute on function public.list_admin_boxes_dashboard(integer) to authenticated;
grant execute on function public.list_admin_pnl_dashboard(integer) to authenticated;
grant execute on function public.list_admin_provider_closure_dashboard(integer) to authenticated;
grant execute on function public.sweep_admin_exceptions() to authenticated;
grant execute on function public.create_framework_agreement_draft(uuid, uuid, text, date, date, numeric, numeric, numeric, text, text, jsonb, jsonb, jsonb, jsonb, jsonb, text, uuid) to authenticated;
grant execute on function public.get_admin_volume_dashboard() to authenticated;

notify pgrst, 'reload schema';
