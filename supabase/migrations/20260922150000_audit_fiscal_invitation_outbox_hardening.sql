-- Audit hardening: fiscal DEMO isolation, credit-note tax engine, quote rounding,
-- invitation outbox delivery payload, franchise economic immutability,
-- finance/credit outbox idempotency keys, client document download grant.

-- ---------------------------------------------------------------------------
-- 1) Morocco tax: DEMO rules cannot stay ACTIVE / cannot drive money paths
-- ---------------------------------------------------------------------------
-- Drop the old check (ACTIVE may be DEMO|VALIDATED) before data cleanup.
-- ACTIVE→DRAFT is blocked by tax content immutability; ACTIVE→RETIRED is allowed.
alter table public.tax_rule_versions drop constraint if exists tax_rules_active_validation_check;

update public.tax_rule_versions
set status = 'RETIRED'
where professional_validation_status = 'DEMO'
  and status = 'ACTIVE';

-- Re-add the stricter check only after DEMO ACTIVE rows are retired.
alter table public.tax_rule_versions
  add constraint tax_rules_active_validation_check
  check (status <> 'ACTIVE' or professional_validation_status = 'VALIDATED');

create or replace function private.resolve_morocco_tax(
  p_category_code text,
  p_effective_on date,
  p_net_minor bigint,
  p_source_rule_version_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  c public.tax_categories%rowtype;
  r public.tax_rule_versions%rowtype;
  tax bigint;
begin
  if p_effective_on is null or p_net_minor = 0 then
    raise exception 'INVALID_TAX_SIMULATION_INPUT' using errcode = '22023';
  end if;
  select * into c from public.tax_categories where code = p_category_code and status = 'ACTIVE';
  if not found then
    raise exception 'TAX_CATEGORY_NOT_FOUND' using errcode = 'P0002';
  end if;
  if c.category_kind = 'CREDIT_NOTE' then
    if p_net_minor >= 0 or p_source_rule_version_id is null then
      raise exception 'CREDIT_NOTE_SOURCE_RULE_REQUIRED' using errcode = '22023';
    end if;
    -- Source rule is the invoice snapshot: keep historical rate even if later retired.
    select * into r
    from public.tax_rule_versions
    where id = p_source_rule_version_id
      and jurisdiction_code = 'MA'
      and status in ('ACTIVE', 'RETIRED');
  else
    if p_net_minor < 0 then
      raise exception 'NEGATIVE_NET_REQUIRES_CREDIT_NOTE' using errcode = '22023';
    end if;
    select * into r
    from public.tax_rule_versions
    where jurisdiction_code = 'MA'
      and category_code = p_category_code
      and status = 'ACTIVE'
      and professional_validation_status = 'VALIDATED'
      and effective_from <= p_effective_on
      and (effective_to is null or effective_to >= p_effective_on)
    order by priority, version desc
    limit 1;
  end if;
  if r.id is null then
    raise exception 'MOROCCO_TAX_RULE_NOT_FOUND' using errcode = 'P0002';
  end if;
  tax := case
    when r.rule_type in ('EXEMPT', 'OUT_OF_SCOPE') then 0
    else private.calculate_tax_minor(p_net_minor, r.rate_basis_points)
  end;
  return jsonb_build_object(
    'jurisdiction_code', 'MA',
    'category_code', p_category_code,
    'effective_on', p_effective_on,
    'tax_rule_version_id', r.id,
    'tax_rule_version', r.version,
    'professional_validation_status', r.professional_validation_status,
    'rule_type', r.rule_type,
    'line_net_minor', p_net_minor::text,
    'tax_rate_basis_points', r.rate_basis_points,
    'tax_amount_minor', tax::text,
    'line_gross_minor', (p_net_minor + tax)::text,
    'rounding_strategy', r.rounding_strategy,
    'legal_reference', r.legal_reference
  );
end;
$$;

create or replace function public.simulate_morocco_tax(
  p_category_code text,
  p_effective_on date,
  p_net_minor bigint,
  p_source_rule_version_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  a uuid := auth.uid();
  c public.tax_categories%rowtype;
  r public.tax_rule_versions%rowtype;
  tax bigint;
begin
  if not private.morocco_tax_admin(a) then
    raise exception 'MOROCCO_TAX_SIMULATION_AAL2_REQUIRED' using errcode = '42501';
  end if;
  if p_effective_on is null or p_net_minor = 0 then
    raise exception 'INVALID_TAX_SIMULATION_INPUT' using errcode = '22023';
  end if;
  select * into c from public.tax_categories where code = p_category_code and status = 'ACTIVE';
  if not found then raise exception 'TAX_CATEGORY_NOT_FOUND' using errcode = 'P0002'; end if;
  if p_source_rule_version_id is not null then
    select * into r from public.tax_rule_versions
    where id = p_source_rule_version_id and jurisdiction_code = 'MA'
      and professional_validation_status in ('DEMO', 'VALIDATED')
      and effective_from <= p_effective_on
      and (effective_to is null or effective_to >= p_effective_on);
  else
    select * into r from public.tax_rule_versions
    where jurisdiction_code = 'MA' and category_code = p_category_code
      and professional_validation_status in ('DEMO', 'VALIDATED')
      and status in ('ACTIVE', 'DRAFT')
      and effective_from <= p_effective_on
      and (effective_to is null or effective_to >= p_effective_on)
    order by case when professional_validation_status = 'VALIDATED' and status = 'ACTIVE' then 0 else 1 end,
             priority, version desc
    limit 1;
  end if;
  if r.id is null then raise exception 'MOROCCO_TAX_RULE_NOT_FOUND' using errcode = 'P0002'; end if;
  tax := case when r.rule_type in ('EXEMPT', 'OUT_OF_SCOPE') then 0 else private.calculate_tax_minor(p_net_minor, r.rate_basis_points) end;
  return jsonb_build_object(
    'jurisdiction_code', 'MA', 'category_code', p_category_code, 'effective_on', p_effective_on,
    'tax_rule_version_id', r.id, 'tax_rule_version', r.version,
    'professional_validation_status', r.professional_validation_status, 'rule_type', r.rule_type,
    'line_net_minor', p_net_minor::text, 'tax_rate_basis_points', r.rate_basis_points,
    'tax_amount_minor', tax::text, 'line_gross_minor', (p_net_minor + tax)::text,
    'rounding_strategy', r.rounding_strategy, 'legal_reference', r.legal_reference,
    'simulation_only', true
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2) Quote revision: same rounding as calculate_tax_minor
-- ---------------------------------------------------------------------------
do $patch$
declare
  src text;
begin
  select pg_get_functiondef('public.create_quote_revision_legacy_0156(uuid,jsonb,text,text,uuid)'::regprocedure) into src;
  if src is null then
    raise exception 'QUOTE_REVISION_LEGACY_MISSING';
  end if;
  src := replace(
    src,
    'v_tax_minor:=round(v_sub::numeric*v_tax.rate_basis_points::numeric/10000)::bigint;',
    'v_tax_minor:=private.calculate_tax_minor(v_sub,v_tax.rate_basis_points);'
  );
  if position('private.calculate_tax_minor(v_sub,v_tax.rate_basis_points)' in src) = 0 then
    raise exception 'QUOTE_TAX_ROUNDING_PATCH_FAILED';
  end if;
  if position('set search_path=pg_catalog,extensions,private' in src) > 0 then
    src := replace(src, 'set search_path=pg_catalog,extensions,private', 'set search_path=pg_catalog,public,extensions,private');
  end if;
  execute src;
end;
$patch$;

-- ---------------------------------------------------------------------------
-- 3) Provider credit notes: tax from versioned engine
-- ---------------------------------------------------------------------------
create or replace function public.issue_provider_credit_note(
  p_invoice_id uuid,
  p_credit_number text,
  p_issued_on date,
  p_subtotal_minor bigint,
  p_tax_minor bigint,
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, private, extensions as $$
declare
  actor uuid := auth.uid();
  invoice public.provider_invoices%rowtype;
  hashed text;
  cached jsonb;
  note uuid;
  journal uuid := extensions.gen_random_uuid();
  receivable uuid;
  revenue uuid;
  tax_account uuid;
  already bigint;
  source_rule uuid;
  resolved jsonb;
  tax_minor bigint;
begin
  select * into invoice from public.provider_invoices where id = p_invoice_id;
  if actor is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], actor) then
    raise exception 'PROVIDER_CREDIT_NOTE_DENIED' using errcode = '42501';
  end if;
  if p_subtotal_minor < 0 or p_subtotal_minor > invoice.subtotal_minor or p_issued_on < invoice.issued_on or length(btrim(p_reason)) < 10 then
    raise exception 'INVALID_CREDIT_NOTE' using errcode = '22023';
  end if;
  if invoice.tax_minor = 0 or invoice.subtotal_minor = 0 or p_subtotal_minor = 0 then
    tax_minor := 0;
  else
    source_rule := nullif(invoice.tax_rule_snapshot->0->>'tax_rule_version_id', '')::uuid;
    if source_rule is null then
      raise exception 'CREDIT_NOTE_SOURCE_RULE_REQUIRED' using errcode = '22023';
    end if;
    resolved := private.resolve_morocco_tax('CREDIT_NOTE', p_issued_on, -p_subtotal_minor, source_rule);
    tax_minor := abs((resolved->>'tax_amount_minor')::bigint);
  end if;
  -- p_tax_minor is retained for signature stability; the versioned engine is authoritative.
  if p_subtotal_minor + tax_minor <= 0 or tax_minor > invoice.tax_minor then
    raise exception 'INVALID_CREDIT_NOTE' using errcode = '22023';
  end if;
  already := private.provider_invoice_credited_minor(invoice.id);
  if already + p_subtotal_minor + tax_minor > invoice.total_minor then
    raise exception 'CREDIT_NOTE_EXCEEDS_INVOICE' using errcode = '23514';
  end if;
  select e.account_id into receivable from public.financial_entries e where e.journal_id = invoice.journal_id and e.direction = 'DEBIT' and e.amount_minor = invoice.total_minor limit 1;
  select e.account_id into revenue from public.financial_entries e where e.journal_id = invoice.journal_id and e.direction = 'CREDIT' and e.amount_minor = invoice.subtotal_minor limit 1;
  if invoice.tax_minor > 0 then
    select e.account_id into tax_account from public.financial_entries e where e.journal_id = invoice.journal_id and e.direction = 'CREDIT' and e.amount_minor = invoice.tax_minor limit 1;
  end if;
  if receivable is null or (p_subtotal_minor > 0 and revenue is null) or (tax_minor > 0 and tax_account is null) then
    raise exception 'INVALID_PROVIDER_LEDGER_ACCOUNT' using errcode = '23514';
  end if;
  hashed := private.canonical_request_hash(jsonb_build_object('invoice', invoice.id, 'number', p_credit_number, 'issued', p_issued_on, 'subtotal', p_subtotal_minor, 'tax', tax_minor, 'reason', btrim(p_reason)));
  cached := private.begin_provider_billing_command(invoice.provider_organization_id, 'provider.billing.credit_note.issue', p_idempotency_key, hashed, actor);
  if cached is not null then return cached; end if;
  insert into public.financial_journals(id, organization_id, journal_type, currency, idempotency_scope, idempotency_key, correlation_id, effective_at, description, created_by)
  values (journal, invoice.provider_organization_id, 'PROVIDER_CREDIT_NOTE', invoice.currency, 'provider.billing.credit_note.issue', p_idempotency_key, p_correlation_id, p_issued_on::timestamptz, 'Provider credit note '||p_credit_number, actor);
  insert into public.financial_entries(organization_id, journal_id, account_id, direction, amount_minor, currency)
  values (invoice.provider_organization_id, journal, receivable, 'CREDIT', p_subtotal_minor + tax_minor, invoice.currency);
  if p_subtotal_minor > 0 then
    insert into public.financial_entries(organization_id, journal_id, account_id, direction, amount_minor, currency)
    values (invoice.provider_organization_id, journal, revenue, 'DEBIT', p_subtotal_minor, invoice.currency);
  end if;
  if tax_minor > 0 then
    insert into public.financial_entries(organization_id, journal_id, account_id, direction, amount_minor, currency)
    values (invoice.provider_organization_id, journal, tax_account, 'DEBIT', tax_minor, invoice.currency);
  end if;
  insert into public.provider_credit_notes(provider_organization_id, invoice_id, credit_number, currency, subtotal_minor, tax_minor, total_minor, reason, issued_on, journal_id, document_hash, correlation_id, created_by)
  values (invoice.provider_organization_id, invoice.id, p_credit_number, invoice.currency, p_subtotal_minor, tax_minor, p_subtotal_minor + tax_minor, btrim(p_reason), p_issued_on, journal, hashed, p_correlation_id, actor)
  returning id into note;
  cached := jsonb_build_object('outcome', 'PROVIDER_CREDIT_NOTE_ISSUED', 'credit_note_id', note, 'invoice_id', invoice.id, 'journal_id', journal, 'subtotal_minor', p_subtotal_minor, 'tax_minor', tax_minor, 'total_minor', p_subtotal_minor + tax_minor, 'tax_rule_version_id', source_rule);
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
  values (invoice.provider_organization_id, actor, 'USER', 'provider.credit_note.issued', 'provider_credit_note', note::text, p_correlation_id, cached, repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key)
  values (invoice.provider_organization_id, 'provider_credit_note', note::text, 'ProviderCreditNoteIssuedV1', p_correlation_id, cached, p_idempotency_key);
  perform private.finish_provider_billing_command(invoice.provider_organization_id, 'provider.billing.credit_note.issue', p_idempotency_key, cached);
  return cached;
end$$;

-- ---------------------------------------------------------------------------
-- 4) Invitation outbox: enrich payload + idempotency_key (guards preserved)
-- ---------------------------------------------------------------------------
create or replace function public.invite_organization_member_by_email(
  p_organization_id uuid,
  p_invited_email text,
  p_role_codes text[],
  p_expires_at timestamptz,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_email text := lower(auth.jwt() ->> 'email');
  v_email text := lower(btrim(p_invited_email));
  v_invited_user_id uuid;
  v_invitation uuid;
  v_is_platform_admin boolean;
  v_request_hash text;
  v_existing private.identity_idempotency_keys%rowtype;
  v_response jsonb;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode = '42501';
  end if;
  if p_organization_id is null
     or v_email is null
     or length(v_email) not between 3 and 320
     or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
     or length(p_idempotency_key) not between 8 and 200 then
    raise exception 'INVALID_INVITATION' using errcode = '22023';
  end if;

  v_is_platform_admin := private.has_platform_role(
    array['SUPER_ADMIN', 'MATRICIA_ADMIN'], v_actor
  );
  if not private.has_org_role(
    p_organization_id,
    array[
      'CLIENT_OWNER', 'CLIENT_ADMIN', 'PROVIDER_OWNER', 'PROVIDER_MANAGER',
      'FRANCHISE_OWNER', 'FRANCHISE_MANAGER'
    ],
    v_actor
  ) and not v_is_platform_admin then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;
  if v_email = v_actor_email then
    raise exception 'SELF_INVITATION_FORBIDDEN' using errcode = '42501';
  end if;
  if p_expires_at <= clock_timestamp()
     or coalesce(cardinality(p_role_codes), 0) = 0
     or exists (
       select 1
       from unnest(p_role_codes) requested(role_code)
       left join public.role_definitions definition on definition.code = requested.role_code
       where definition.code is null
          or definition.scope_type = 'PLATFORM'
          or definition.scope_type not in ('ORGANIZATION', 'FRANCHISE')
     ) then
    raise exception 'INVALID_INVITATION' using errcode = '22023';
  end if;

  if not v_is_platform_admin and exists (
    select 1
    from unnest(p_role_codes) requested(role_code)
    where right(requested.role_code, 6) = '_OWNER'
      and not exists (
        select 1
        from public.organization_memberships membership
        join public.organization_member_roles member_role
          on member_role.membership_id = membership.id
        where membership.organization_id = p_organization_id
          and membership.user_id = v_actor
          and membership.status = 'ACTIVE'
          and member_role.revoked_at is null
          and split_part(member_role.role_code, '_', 1)
            = split_part(requested.role_code, '_', 1)
      )
  ) then
    raise exception 'CROSS_DOMAIN_OWNER_INVITATION_FORBIDDEN' using errcode = '42501';
  end if;

  v_request_hash := private.canonical_request_hash(jsonb_build_object(
    'operation', 'identity.email.invitation.v1',
    'organization_id', p_organization_id,
    'invited_email', v_email,
    'role_codes', (select jsonb_agg(role_code order by role_code) from unnest(p_role_codes) role_code),
    'expires_at', p_expires_at
  ));

  perform pg_advisory_xact_lock(
    hashtextextended(v_actor::text || ':identity.email.invitation:' || p_idempotency_key, 0)
  );
  select * into v_existing
  from private.identity_idempotency_keys
  where actor_user_id = v_actor
    and operation_scope = 'identity.email.invitation'
    and key = p_idempotency_key;
  if found then
    if v_existing.request_hash <> v_request_hash then
      raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode = '22000';
    end if;
    return v_existing.response_body;
  end if;

  select auth_user.id into v_invited_user_id
  from auth.users auth_user
  where lower(auth_user.email) = v_email;

  insert into public.organization_invitations (
    organization_id, invited_user_id, invited_email, invited_by, expires_at
  ) values (
    p_organization_id, v_invited_user_id, v_email, v_actor, p_expires_at
  ) returning id into v_invitation;

  insert into public.organization_invitation_roles (invitation_id, role_code)
  select v_invitation, requested.role_code
  from unnest(p_role_codes) requested(role_code)
  on conflict do nothing;

  v_response := jsonb_build_object(
    'outcome', 'INVITATION_CREATED',
    'invitation_id', v_invitation,
    'organization_id', p_organization_id
  );

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, previous_hash, event_hash
  ) values (
    p_organization_id, v_actor, 'USER', 'organization.invitation.created',
    'organization_invitation', v_invitation::text, p_correlation_id,
    jsonb_build_object('role_count', cardinality(p_role_codes), 'channel', 'EMAIL'),
    null, repeat('0', 64)
  );
  insert into public.event_outbox (
    organization_id, aggregate_type, aggregate_id, event_type,
    correlation_id, payload, idempotency_key
  ) values (
    p_organization_id, 'organization_invitation', v_invitation::text,
    'OrganizationEmailInvitationRequestedV1', p_correlation_id,
    jsonb_build_object(
      'invitation_id', v_invitation,
      'organization_id', p_organization_id,
      'invited_email', v_email,
      'expires_at', p_expires_at,
      'role_codes', p_role_codes
    ),
    p_idempotency_key
  );

  insert into private.identity_idempotency_keys (
    actor_user_id, operation_scope, key, request_hash, response_body, expires_at
  ) values (
    v_actor, 'identity.email.invitation', p_idempotency_key, v_request_hash,
    v_response, clock_timestamp() + interval '7 days'
  );
  return v_response;
end;
$$;

create or replace function public.load_organization_invitation_email_v1(p_invitation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  inv public.organization_invitations%rowtype;
  org_name text;
  roles text[];
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'INVITATION_EMAIL_LOAD_DENIED' using errcode = '42501';
  end if;
  select * into inv from public.organization_invitations where id = p_invitation_id;
  if not found or inv.status <> 'PENDING' or inv.expires_at <= clock_timestamp() then
    raise exception 'INVITATION_NOT_DELIVERABLE' using errcode = 'P0002';
  end if;
  select name into org_name from public.organizations where id = inv.organization_id;
  select coalesce(array_agg(role_code order by role_code), '{}') into roles
  from public.organization_invitation_roles where invitation_id = inv.id;
  return jsonb_build_object(
    'invitation_id', inv.id,
    'organization_id', inv.organization_id,
    'organization_name', org_name,
    'invited_email', inv.invited_email,
    'expires_at', inv.expires_at,
    'role_codes', roles
  );
end;
$$;

revoke all on function public.load_organization_invitation_email_v1(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.load_organization_invitation_email_v1(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 5) Client bound document download authorization
-- ---------------------------------------------------------------------------
create or replace function public.authorize_client_bound_document(p_document_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  actor uuid := auth.uid();
  document public.client_compliance_documents%rowtype;
begin
  if actor is null then raise exception 'UNAUTHENTICATED' using errcode = '42501'; end if;
  select d.* into document
  from public.client_compliance_documents d
  where d.id = p_document_id
    and d.status = 'VERIFIED'
    and d.scan_status = 'CLEAN'
    and d.current_scan_result_id is not null
    and (d.expires_on is null or d.expires_on >= current_date)
    and private.has_org_role(d.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_MEMBER','CLIENT_VIEWER'], actor)
    and exists (
      select 1 from private.client_document_scan_results scan
      where scan.id = d.current_scan_result_id
        and scan.document_id = d.id
        and scan.organization_id = d.organization_id
        and scan.result = 'CLEAN'
        and scan.computed_sha256 = d.declared_sha256
    );
  if not found then raise exception 'CLIENT_DOCUMENT_DENIED' using errcode = '42501'; end if;
  insert into public.audit_events(
    organization_id, actor_user_id, actor_type, action, resource_type,
    resource_id, correlation_id, metadata, event_hash
  ) values (
    document.organization_id, actor, 'USER', 'client.document.downloaded',
    'client_compliance_document', document.id::text, extensions.gen_random_uuid(),
    jsonb_build_object('document_version', document.version), repeat('0', 64)
  );
  return jsonb_build_object(
    'outcome', 'CLIENT_DOCUMENT_AUTHORIZED',
    'document_id', document.id,
    'bucket', document.storage_bucket,
    'object_path', document.storage_object_path,
    'file_name', document.original_file_name,
    'mime_type', document.declared_mime_type,
    'size_bytes', document.declared_size_bytes
  );
end;
$$;

revoke all on function public.authorize_client_bound_document(uuid)
  from public, anon, service_role;
grant execute on function public.authorize_client_bound_document(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Franchise economic immutability + STANDARD fee alignment
-- ---------------------------------------------------------------------------
create or replace function private.prevent_franchise_economic_rule_change()
returns trigger language plpgsql set search_path = pg_catalog as $$
begin
  raise exception 'IMMUTABLE_FRANCHISE_ECONOMIC_RULE' using errcode = '55000';
end$$;

-- Align STANDARD seed before locking the table: entry fee required (>0), shares 50/25/25.
update public.franchise_economic_rule_versions
set entry_fee_minor = 1
where franchise_type = 'STANDARD' and status = 'ACTIVE' and entry_fee_minor = 0;

drop trigger if exists franchise_economic_rules_immutable on public.franchise_economic_rule_versions;
create trigger franchise_economic_rules_immutable
before update or delete on public.franchise_economic_rule_versions
for each row execute function private.prevent_franchise_economic_rule_change();

revoke all on function private.prevent_franchise_economic_rule_change()
  from public, anon, authenticated, service_role;

alter table public.franchise_economic_rule_versions
  drop constraint if exists franchise_economic_standard_entry_fee_check;
alter table public.franchise_economic_rule_versions
  add constraint franchise_economic_standard_entry_fee_check
  check (franchise_type <> 'STANDARD' or status <> 'ACTIVE' or entry_fee_minor > 0);

-- ---------------------------------------------------------------------------
-- 7) Finance / credit outbox idempotency_key
-- ---------------------------------------------------------------------------
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
set search_path = pg_catalog, public, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_journal_id uuid := extensions.gen_random_uuid();
  v_inserted integer;
  v_existing public.idempotency_keys%rowtype;
  v_previous_hash text;
  v_debit bigint;
  v_credit bigint;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if not (
    private.has_org_role(p_organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING'], v_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], v_actor)
  ) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if length(p_idempotency_key) not between 8 and 200 or p_request_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'INVALID_IDEMPOTENCY' using errcode='22023';
  end if;
  if p_currency !~ '^[A-Z]{3}$' or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) < 2 then
    raise exception 'INVALID_JOURNAL' using errcode='22023';
  end if;

  perform 1 from public.organizations where id=p_organization_id and status='ACTIVE' for update;
  if not found then raise exception 'ORGANIZATION_NOT_ACTIVE' using errcode='23514'; end if;

  insert into public.idempotency_keys (organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values (p_organization_id,'finance.post_journal',p_idempotency_key,p_request_hash,v_actor,now()+interval '7 days')
  on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    select * into v_existing from public.idempotency_keys
    where organization_id=p_organization_id and operation_scope='finance.post_journal' and key=p_idempotency_key;
    if v_existing.request_hash <> p_request_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
    if v_existing.status='COMPLETED' then return (v_existing.response_body->>'journal_id')::uuid; end if;
    raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';
  end if;

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

  select event_hash into v_previous_hash from public.audit_events
  where organization_id=p_organization_id order by id desc limit 1;
  insert into public.audit_events
    (organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values
    (p_organization_id,v_actor,'USER','financial.journal.posted','financial_journal',v_journal_id::text,p_correlation_id,
     jsonb_build_object('currency',p_currency,'debit_minor',v_debit),v_previous_hash,
     encode(extensions.digest(concat_ws('|',coalesce(v_previous_hash,''),p_organization_id::text,v_journal_id::text,p_request_hash),'sha256'),'hex'));
  insert into public.event_outbox (organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values (p_organization_id,'financial_journal',v_journal_id::text,'FinancialJournalPostedV1',p_correlation_id,
          jsonb_build_object('journal_id',v_journal_id,'organization_id',p_organization_id,'currency',p_currency,'debit_minor',v_debit),
          p_idempotency_key);
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
set search_path = pg_catalog, public, extensions, private
as $$
declare
  v_actor uuid := auth.uid();
  v_inserted integer;
  v_existing public.idempotency_keys%rowtype;
  v_entry_id bigint;
  v_balance bigint;
  v_previous_hash text;
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode='42501'; end if;
  if not (
    private.has_org_role(p_organization_id, array['CLIENT_OWNER','CLIENT_ACCOUNTING','PROVIDER_OWNER','PROVIDER_ACCOUNTING','FRANCHISE_OWNER','FRANCHISE_ACCOUNTING'], v_actor)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'], v_actor)
  ) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if length(p_idempotency_key) not between 8 and 200 or p_request_hash !~ '^[0-9a-f]{64}$' then raise exception 'INVALID_IDEMPOTENCY' using errcode='22023'; end if;
  if p_entry_type not in ('GRANT','RESERVE','RELEASE','CONSUME','EXPIRE','ADJUSTMENT') or p_quantity=0 then raise exception 'INVALID_CREDIT_ENTRY' using errcode='22023'; end if;
  if (p_entry_type in ('GRANT','RELEASE') and p_quantity<0) or (p_entry_type in ('RESERVE','CONSUME','EXPIRE') and p_quantity>0) then raise exception 'INVALID_CREDIT_SIGN' using errcode='23514'; end if;

  perform 1 from public.credit_wallets where id=p_wallet_id and organization_id=p_organization_id for update;
  if not found then raise exception 'WALLET_NOT_FOUND' using errcode='P0002'; end if;
  insert into public.idempotency_keys (organization_id,operation_scope,key,request_hash,created_by,expires_at)
  values (p_organization_id,'credits.append',p_idempotency_key,p_request_hash,v_actor,now()+interval '7 days') on conflict do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted=0 then
    select * into v_existing from public.idempotency_keys where organization_id=p_organization_id and operation_scope='credits.append' and key=p_idempotency_key;
    if v_existing.request_hash<>p_request_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000'; end if;
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

  select event_hash into v_previous_hash from public.audit_events where organization_id=p_organization_id order by id desc limit 1;
  insert into public.audit_events
    (organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
  values
    (p_organization_id,v_actor,'USER','credit.entry.appended','credit_ledger_entry',v_entry_id::text,p_correlation_id,
     jsonb_build_object('entry_type',p_entry_type,'quantity',p_quantity,'balance',v_balance),v_previous_hash,
     encode(extensions.digest(concat_ws('|',coalesce(v_previous_hash,''),p_organization_id::text,v_entry_id::text,p_request_hash),'sha256'),'hex'));
  insert into public.event_outbox (organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values (p_organization_id,'credit_wallet',p_wallet_id::text,'CreditLedgerEntryAppendedV1',p_correlation_id,
          jsonb_build_object('entry_id',v_entry_id,'wallet_id',p_wallet_id,'entry_type',p_entry_type,'quantity',p_quantity,'balance',v_balance),
          p_idempotency_key);
  update public.idempotency_keys set status='COMPLETED',response_code=201,response_body=jsonb_build_object('entry_id',v_entry_id,'balance',v_balance),completed_at=clock_timestamp()
  where organization_id=p_organization_id and operation_scope='credits.append' and key=p_idempotency_key;
  return v_entry_id;
end;
$$;

notify pgrst, 'reload schema';
