-- TEMPORARY. Suspends the platform account-security obligation (AAL2)
-- so a session at AAL1 can open the administration screens and run
-- credit/box activation writes that previously required jwt aal=aal2.
-- Role rows and the stored mfa_required policy are unchanged.
-- Restore by reapplying:
--   private.has_platform_role + public.get_my_account_security_requirement
--     from 20260911002700_identity_security_followup.sql
--     and 20260911002500_identity_security_hardening.sql
--   public.activate_benefit_version / activate_box_version / link_plan_box_rule
--     from 20260921120000_admin_boxes_pnl_closure_exceptions.sql

create or replace function private.has_platform_role(
  allowed_roles text[],
  target_user_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = pg_catalog, private
as $$
  select exists (
    select 1
    from public.platform_user_roles platform_role
    where platform_role.user_id = target_user_id
      and platform_role.revoked_at is null
      and platform_role.role_code = any(allowed_roles)
  );
$$;

revoke all on function private.has_platform_role(text[], uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.has_platform_role(text[], uuid) to authenticated;

create or replace function public.get_my_account_security_requirement()
returns table (
  mfa_required boolean,
  password_allowed boolean,
  current_aal text,
  requirement_satisfied boolean,
  matched_role_codes text[]
)
language plpgsql
stable
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_aal text := coalesce(auth.jwt() ->> 'aal', 'aal1');
  v_roles text[];
  v_password_allowed boolean;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  select coalesce(array_agg(platform_role.role_code order by platform_role.role_code), '{}'::text[]),
         coalesce(bool_and(policy.password_allowed), true)
    into v_roles, v_password_allowed
  from public.platform_user_roles platform_role
  join public.role_security_policy_versions policy
    on policy.role_code = platform_role.role_code
   and policy.status = 'ACTIVE'
   and policy.effective_from <= clock_timestamp()
   and (policy.effective_to is null or policy.effective_to > clock_timestamp())
  where platform_role.user_id = v_actor
    and platform_role.revoked_at is null;
  return query select false, v_password_allowed, v_aal, true, v_roles;
end;
$$;

revoke all on function public.get_my_account_security_requirement()
  from public, anon, authenticated, service_role;
grant execute on function public.get_my_account_security_requirement()
  to authenticated;

-- Same bodies as 20260921120000, without jwt aal=aal2 gates.
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
  if a is null or not private.credits_admin_access(a) then
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
  if a is null or not private.credits_admin_access(a) then
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
  if a is null or not private.credits_admin_access(a) then
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

notify pgrst, 'reload schema';
