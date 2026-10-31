-- RFQ-REGION-001: providers declare their intervention regions through a governed command.
-- Matching already reads provider_match_profiles.region_codes; until now only seeds wrote it,
-- so every real provider was excluded with REGION_MISMATCH.
-- Additive: one immutable history table, one validation helper, one command. No existing row is rewritten.

begin;

create or replace function private.morocco_region_codes()
returns text[] language sql immutable set search_path = pg_catalog as $$
  select array[
    'TANGER_TETOUAN_AL_HOCEIMA', 'ORIENTAL', 'FES_MEKNES', 'RABAT_SALE_KENITRA',
    'BENI_MELLAL_KHENIFRA', 'CASABLANCA_SETTAT', 'MARRAKECH_SAFI', 'DRAA_TAFILALET',
    'SOUSS_MASSA', 'GUELMIM_OUED_NOUN', 'LAAYOUNE_SAKIA_EL_HAMRA', 'DAKHLA_OUED_ED_DAHAB'
  ]::text[]
$$;
revoke all on function private.morocco_region_codes() from public, anon, authenticated, service_role;

alter table private.provider_qualification_command_keys
  drop constraint provider_qualification_command_keys_operation_scope_check;
alter table private.provider_qualification_command_keys
  add constraint provider_qualification_command_keys_operation_scope_check check (operation_scope in (
    'provider.profile.submit','provider.company.decide','provider.service.request','provider.document.version',
    'provider.document.review','provider.capacity.declare','provider.qualification.decide','provider.restriction.decide',
    'provider.regions.declare'
  ));

create table public.provider_region_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  provider_organization_id uuid not null references public.provider_match_profiles(provider_organization_id) on delete restrict,
  version_number integer not null check (version_number > 0),
  region_codes text[] not null check (cardinality(region_codes) between 1 and 12 and array_position(region_codes, null) is null),
  reason text not null check (length(btrim(reason)) between 3 and 500),
  declared_by uuid not null references auth.users(id) on delete restrict,
  declared_at timestamptz not null default clock_timestamp(),
  unique (provider_organization_id, version_number)
);
create index provider_region_versions_history_idx on public.provider_region_versions(provider_organization_id, version_number desc);
create trigger provider_region_versions_immutable before update or delete on public.provider_region_versions
  for each row execute function private.prevent_provider_snapshot_mutation();

alter table public.provider_region_versions enable row level security;
create policy provider_region_versions_scoped_read on public.provider_region_versions for select to authenticated
  using (private.is_active_org_member(provider_organization_id)
    or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR']));
revoke all on public.provider_region_versions from anon, authenticated, service_role;
grant select on public.provider_region_versions to authenticated;

create or replace function public.declare_provider_regions(
  p_provider_organization_id uuid,
  p_region_codes text[],
  p_reason text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer set search_path = pg_catalog as $$
declare
  v_actor uuid := auth.uid();
  v_codes text[];
  v_hash text;
  v_command uuid;
  v_replay jsonb;
  v_version integer;
  v_id uuid;
  v_response jsonb;
begin
  if not private.can_manage_provider(p_provider_organization_id, v_actor) then
    raise exception 'PROVIDER_SCOPE_DENIED' using errcode = '42501';
  end if;
  select coalesce(array_agg(distinct upper(btrim(code)) order by upper(btrim(code))), '{}'::text[])
    into v_codes
    from unnest(coalesce(p_region_codes, '{}'::text[])) code
    where btrim(coalesce(code, '')) <> '';
  if cardinality(v_codes) = 0
     or not (v_codes <@ private.morocco_region_codes())
     or length(btrim(coalesce(p_reason, ''))) not between 3 and 500 then
    raise exception 'INVALID_PROVIDER_REGIONS' using errcode = '22023';
  end if;
  if not exists (select 1 from public.provider_match_profiles p where p.provider_organization_id = p_provider_organization_id) then
    raise exception 'PROVIDER_PROFILE_REQUIRED' using errcode = '23514';
  end if;

  v_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'operation', 'provider.regions.declare.v1', 'organization_id', p_provider_organization_id,
    'regions', to_jsonb(v_codes), 'reason', btrim(p_reason)
  )::text, 'UTF8'), 'sha256'), 'hex');
  select b.command_id, b.response_body into v_command, v_replay
    from private.begin_provider_qualification_command(v_actor, 'provider.regions.declare', p_idempotency_key, v_hash) b;
  if v_replay is not null then return v_replay; end if;

  perform pg_advisory_xact_lock(hashtextextended('provider-regions:' || p_provider_organization_id::text, 0));
  select coalesce(max(version_number), 0) + 1 into v_version
    from public.provider_region_versions where provider_organization_id = p_provider_organization_id;
  insert into public.provider_region_versions(provider_organization_id, version_number, region_codes, reason, declared_by)
    values (p_provider_organization_id, v_version, v_codes, btrim(p_reason), v_actor)
    returning id into v_id;
  update public.provider_match_profiles
    set region_codes = v_codes, updated_at = clock_timestamp(), row_version = row_version + 1
    where provider_organization_id = p_provider_organization_id;

  v_response := jsonb_build_object(
    'outcome', 'PROVIDER_REGIONS_DECLARED', 'region_version_id', v_id, 'version_number', v_version,
    'region_codes', to_jsonb(v_codes), 'command_id', v_command
  );
  insert into public.audit_events(organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash)
    values (p_provider_organization_id, v_actor, 'USER', 'provider.regions.declared', 'provider_region_version', v_id::text, p_correlation_id,
      jsonb_build_object('region_codes', to_jsonb(v_codes), 'version_number', v_version, 'command_id', v_command), repeat('0', 64));
  insert into public.event_outbox(organization_id, aggregate_type, aggregate_id, event_type, correlation_id, payload, idempotency_key, causation_id)
    values (p_provider_organization_id, 'provider_regions', p_provider_organization_id::text, 'ProviderRegionsDeclaredV1', p_correlation_id,
      jsonb_build_object('provider_organization_id', p_provider_organization_id, 'region_codes', to_jsonb(v_codes), 'version_number', v_version),
      p_idempotency_key, v_command);
  perform private.finish_provider_qualification_command(v_actor, 'provider.regions.declare', p_idempotency_key, v_response);
  return v_response;
end$$;

revoke all on function public.declare_provider_regions(uuid, text[], text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.declare_provider_regions(uuid, text[], text, text, uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
