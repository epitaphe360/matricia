-- NON-PRODUCTION ONLY — activates Morocco tax rules as VALIDATED for application testing.
-- Must never be placed in supabase/migrations and must never run on production:
-- production rules require a real Moroccan chartered-accountant validation.
--
-- For each active tax category (except CREDIT_NOTE, which derives from the source invoice rule),
-- inserts a new version copying the rate and rule type of the latest DEMO version,
-- with status ACTIVE and professional_validation_status VALIDATED.
-- Existing rows are never updated (tax rule content is immutable).
-- Rollback: supabase/scripts/test-retire-tax-rules.sql

-- Uncomment the next line to confirm the target database is NOT production:
-- select set_config('matricia.confirm_non_production', 'I_CONFIRM_THIS_IS_NOT_PRODUCTION', false);

do $$
declare
  approver uuid;
  category record;
  source_rule public.tax_rule_versions%rowtype;
  next_version integer;
  hash text;
  inserted uuid;
  created integer := 0;
begin
  if coalesce(current_setting('matricia.confirm_non_production', true), '') <> 'I_CONFIRM_THIS_IS_NOT_PRODUCTION' then
    raise exception 'NON_PRODUCTION_CONFIRMATION_REQUIRED: uncomment the set_config line at the top of this script';
  end if;

  select role.user_id into approver
  from public.platform_user_roles role
  where role.role_code = 'SUPER_ADMIN' and role.revoked_at is null
  order by role.granted_at
  limit 1;
  if approver is null then
    raise exception 'NO_SUPER_ADMIN_FOUND: a SUPER_ADMIN user is required as test approver';
  end if;

  for category in
    select c.code from public.tax_categories c
    where c.status = 'ACTIVE' and c.category_kind <> 'CREDIT_NOTE'
    order by c.code
  loop
    if exists (
      select 1 from public.tax_rule_versions r
      where r.jurisdiction_code = 'MA' and r.category_code = category.code
        and r.status = 'ACTIVE' and r.professional_validation_status = 'VALIDATED'
    ) then
      raise notice 'SKIP %: a VALIDATED ACTIVE rule already exists', category.code;
      continue;
    end if;

    select * into source_rule from public.tax_rule_versions r
    where r.jurisdiction_code = 'MA' and r.category_code = category.code
    order by r.version desc
    limit 1;
    if source_rule.id is null then
      raise notice 'SKIP %: no source version to copy', category.code;
      continue;
    end if;

    select coalesce(max(version), 0) + 1 into next_version
    from public.tax_rule_versions
    where jurisdiction_code = 'MA' and category_code = category.code;

    hash := private.canonical_request_hash(jsonb_build_object(
      'jurisdiction', 'MA', 'category', category.code, 'version', next_version,
      'rate_bps', source_rule.rate_basis_points, 'rule_type', source_rule.rule_type,
      'environment_class', 'NON_PRODUCTION_TEST'
    ));

    insert into public.tax_rule_versions(
      jurisdiction_code, category_code, version, rate_basis_points, effective_from, effective_to,
      status, professional_validation_status, rule_type, priority, conditions, legal_reference,
      rounding_strategy, content_hash, change_reason, created_by,
      approved_by, approved_at, validation_reference
    ) values (
      'MA', category.code, next_version, source_rule.rate_basis_points, date '2026-01-01', null,
      'ACTIVE', 'VALIDATED', source_rule.rule_type, source_rule.priority,
      jsonb_build_object('environment_class', 'NON_PRODUCTION_TEST', 'requires_accountant_validation', true),
      'TEST NON-PRODUCTION — taux de démonstration, validation expert-comptable Maroc requise avant production',
      source_rule.rounding_strategy, hash,
      'Activation de test non-production; interdite comme vérité fiscale de production', approver,
      approver, clock_timestamp(), 'TEST-NON-PROD'
    ) returning id into inserted;

    insert into public.tax_rule_validation_events(
      tax_rule_version_id, decision, professional_validation_status, validation_reference,
      reason, rule_content_hash, decided_by, correlation_id
    ) values (
      inserted, 'APPROVE', 'VALIDATED', 'TEST-NON-PROD',
      'Validation de test non-production pour recette applicative', hash, approver,
      extensions.gen_random_uuid()
    );

    created := created + 1;
    raise notice 'ACTIVATED % v% (% bps, %)', category.code, next_version, source_rule.rate_basis_points, source_rule.rule_type;
  end loop;

  raise notice 'DONE: % test rule(s) activated', created;
end
$$;

select category_code, version, rate_basis_points, rule_type, status, professional_validation_status, validation_reference
from public.tax_rule_versions
where jurisdiction_code = 'MA' and status = 'ACTIVE'
order by category_code;
