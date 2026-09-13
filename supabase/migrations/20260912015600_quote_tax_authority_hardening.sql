-- P07/P14: make the versioned Morocco tax snapshot authoritative for quote revisions.

create or replace function private.assert_quote_tax_rule(
  p_tax_rule_version_id uuid,
  p_expected_category text,
  p_effective_on date
) returns public.tax_rule_versions
language plpgsql
stable
security definer
set search_path=pg_catalog,public,private
as $$
declare
  v_rule public.tax_rule_versions%rowtype;
begin
  if p_effective_on is null
    or p_expected_category is null
    or p_expected_category !~ '^[A-Z][A-Z0-9_]{2,79}$'
    or not exists (
      select 1 from public.tax_categories
      where code=p_expected_category and status='ACTIVE'
    )
  then
    raise exception 'QUOTE_TAX_CATEGORY_INVALID' using errcode='22023';
  end if;

  select tr.* into v_rule
  from public.tax_rule_versions tr
  join public.tax_categories tc on tc.code=tr.category_code and tc.status='ACTIVE'
  where tr.id=p_tax_rule_version_id
    and tr.jurisdiction_code='MA'
    and tr.category_code=p_expected_category
    and tr.status='ACTIVE'
    and tr.professional_validation_status='VALIDATED'
    and tr.effective_from<=p_effective_on
    and (tr.effective_to is null or tr.effective_to>=p_effective_on);

  if not found then
    raise exception 'QUOTE_TAX_RULE_INVALID' using errcode='22023';
  end if;
  return v_rule;
end;
$$;

alter function public.create_quote_revision(uuid,jsonb,text,text,uuid)
  rename to create_quote_revision_legacy_0156;
revoke all on function public.create_quote_revision_legacy_0156(uuid,jsonb,text,text,uuid)
  from public,anon,authenticated,service_role;

create function public.create_quote_revision(
  p_rfq_provider_id uuid,
  p_payload jsonb,
  p_change_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path=pg_catalog,public,private
as $$
declare
  v_actor uuid:=auth.uid();
  v_provider_organization_id uuid;
  v_category text;
  v_effective_on date;
  v_line jsonb;
begin
  if v_actor is null then
    raise exception 'UNAUTHENTICATED' using errcode='42501';
  end if;
  if p_payload is null
    or jsonb_typeof(p_payload)<>'object'
    or coalesce(p_payload->>'proposed_start_date','')!~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    or jsonb_typeof(coalesce(p_payload->'items','null'::jsonb))<>'array'
    or jsonb_array_length(p_payload->'items')=0
  then
    raise exception 'QUOTE_PAYLOAD_INVALID' using errcode='22023';
  end if;
  begin
    v_effective_on:=(p_payload->>'proposed_start_date')::date;
  exception when datetime_field_overflow or invalid_datetime_format then
    raise exception 'QUOTE_PAYLOAD_INVALID' using errcode='22023';
  end;

  select rp.provider_organization_id,
         nullif(btrim(srv.required_quote_data->>'tax_category_code'),'')
    into v_provider_organization_id,v_category
  from public.rfq_providers rp
  join public.rfqs r on r.id=rp.rfq_id
  join public.service_request_versions srv
    on srv.id=r.request_version_id and srv.request_id=r.request_id
  where rp.id=p_rfq_provider_id;

  if not found then
    raise exception 'RFQ_INVITATION_NOT_FOUND' using errcode='P0002';
  end if;
  if not private.has_org_role(
    v_provider_organization_id,
    array['PROVIDER_OWNER','PROVIDER_MANAGER','PROVIDER_SALES'],
    v_actor
  ) then
    raise exception 'QUOTE_PROVIDER_SCOPE_DENIED' using errcode='42501';
  end if;

  if v_category is null
    or v_category!~ '^[A-Z][A-Z0-9_]{2,79}$'
    or not exists (
      select 1 from public.tax_categories where code=v_category and status='ACTIVE'
    )
  then
    raise exception 'QUOTE_TAX_CATEGORY_INVALID' using errcode='22023';
  end if;

  for v_line in select value from jsonb_array_elements(p_payload->'items') loop
    perform private.assert_quote_tax_rule(
      (v_line->>'tax_rule_version_id')::uuid,
      v_category,
      v_effective_on
    );
  end loop;

  return public.create_quote_revision_legacy_0156(
    p_rfq_provider_id,
    p_payload,
    p_change_reason,
    p_idempotency_key,
    p_correlation_id
  );
exception
  when invalid_text_representation then
    raise exception 'QUOTE_TAX_RULE_INVALID' using errcode='22023';
end;
$$;

revoke all on function private.assert_quote_tax_rule(uuid,text,date) from public,anon,authenticated,service_role;
revoke all on function public.create_quote_revision(uuid,jsonb,text,text,uuid) from public,anon,service_role;
grant execute on function public.create_quote_revision(uuid,jsonb,text,text,uuid) to authenticated;
