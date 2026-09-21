-- Franchisee supervision of mandated-library operational records (SELECT only).
-- Additive policies; existing client/provider/platform policies stay unchanged.
-- Multi-table walks live in SECURITY DEFINER helpers so policy expressions never
-- join sibling "id" columns (ERROR 42702) and inner RLS cannot hide the chain.

create or replace function private.franchise_mandated_library(p_library_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select p_library_id is not null and exists (
    select 1
    from public.franchises f
    where f.library_id = p_library_id
      and f.status = 'ACTIVE'
      and private.franchise_access(f.id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_diagnostic_run(p_run_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.diagnostic_runs run
    where run.id = p_run_id
      and private.franchise_mandated_library(run.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_request(p_request_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.service_requests request
    where request.id = p_request_id
      and private.franchise_mandated_library(request.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_rfq(p_rfq_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.rfqs rfq
    join public.service_requests request on request.id = rfq.request_id
    where rfq.id = p_rfq_id
      and private.franchise_mandated_library(request.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_quote(p_quote_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.quotes quote
    join public.rfqs rfq on rfq.id = quote.rfq_id
    join public.service_requests request on request.id = rfq.request_id
    where quote.id = p_quote_id
      and private.franchise_mandated_library(request.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_contract(p_contract_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.contract_versions version
    join public.quote_versions quote_version on quote_version.id = version.selected_quote_version_id
    join public.quotes quote on quote.id = quote_version.quote_id
    join public.rfqs rfq on rfq.id = quote.rfq_id
    join public.service_requests request on request.id = rfq.request_id
    where version.contract_id = p_contract_id
      and private.franchise_mandated_library(request.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_matching_run(p_run_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.matching_runs run
    join public.service_requests request on request.id = run.request_id
    where run.id = p_run_id
      and private.franchise_mandated_library(request.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_catalog_service(p_service_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.catalog_services service
    where service.id = p_service_id
      and private.franchise_mandated_library(service.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_document_family(p_family_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.provider_document_versions version
    join public.provider_document_service_links link on link.document_version_id = version.id
    join public.provider_services provider_service on provider_service.id = link.provider_service_id
    join public.catalog_services service on service.id = provider_service.service_id
    where version.family_id = p_family_id
      and private.franchise_mandated_library(service.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_document_version(p_version_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.provider_document_service_links link
    join public.provider_services provider_service on provider_service.id = link.provider_service_id
    join public.catalog_services service on service.id = provider_service.service_id
    where link.document_version_id = p_version_id
      and private.franchise_mandated_library(service.library_id, p_actor)
  );
$$;

create or replace function private.franchise_supervises_thread(p_thread_id uuid, p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1
    from public.internal_message_threads thread
    join public.service_requests request on request.id = thread.service_request_id
    where thread.id = p_thread_id
      and private.franchise_mandated_library(request.library_id, p_actor)
  );
$$;

revoke all on function private.franchise_mandated_library(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_diagnostic_run(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_request(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_rfq(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_quote(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_contract(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_matching_run(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_catalog_service(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_document_family(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_document_version(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.franchise_supervises_thread(uuid, uuid) from public, anon, authenticated, service_role;

grant execute on function private.franchise_mandated_library(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_diagnostic_run(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_request(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_rfq(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_quote(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_contract(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_matching_run(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_catalog_service(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_document_family(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_document_version(uuid, uuid) to authenticated;
grant execute on function private.franchise_supervises_thread(uuid, uuid) to authenticated;

drop policy if exists diagnostic_runs_franchise_library_read on public.diagnostic_runs;
create policy diagnostic_runs_franchise_library_read on public.diagnostic_runs
  for select to authenticated
  using (private.franchise_mandated_library(diagnostic_runs.library_id));

drop policy if exists diagnostic_anomalies_franchise_library_read on public.diagnostic_anomalies;
create policy diagnostic_anomalies_franchise_library_read on public.diagnostic_anomalies
  for select to authenticated
  using (private.franchise_supervises_diagnostic_run(diagnostic_anomalies.diagnostic_run_id));

drop policy if exists diagnostic_recommendations_franchise_library_read on public.diagnostic_recommendations;
create policy diagnostic_recommendations_franchise_library_read on public.diagnostic_recommendations
  for select to authenticated
  using (private.franchise_supervises_diagnostic_run(diagnostic_recommendations.diagnostic_run_id));

drop policy if exists diagnostic_opportunities_franchise_library_read on public.diagnostic_opportunities;
create policy diagnostic_opportunities_franchise_library_read on public.diagnostic_opportunities
  for select to authenticated
  using (private.franchise_supervises_diagnostic_run(diagnostic_opportunities.diagnostic_run_id));

drop policy if exists service_requests_franchise_library_read on public.service_requests;
create policy service_requests_franchise_library_read on public.service_requests
  for select to authenticated
  using (private.franchise_mandated_library(service_requests.library_id));

drop policy if exists service_request_versions_franchise_library_read on public.service_request_versions;
create policy service_request_versions_franchise_library_read on public.service_request_versions
  for select to authenticated
  using (private.franchise_mandated_library(service_request_versions.library_id));

drop policy if exists matching_runs_franchise_library_read on public.matching_runs;
create policy matching_runs_franchise_library_read on public.matching_runs
  for select to authenticated
  using (private.franchise_supervises_request(matching_runs.request_id));

drop policy if exists matching_candidates_franchise_library_read on public.matching_candidates;
create policy matching_candidates_franchise_library_read on public.matching_candidates
  for select to authenticated
  using (private.franchise_supervises_matching_run(matching_candidates.matching_run_id));

drop policy if exists rfqs_franchise_library_read on public.rfqs;
create policy rfqs_franchise_library_read on public.rfqs
  for select to authenticated
  using (private.franchise_supervises_request(rfqs.request_id));

drop policy if exists rfq_providers_franchise_library_read on public.rfq_providers;
create policy rfq_providers_franchise_library_read on public.rfq_providers
  for select to authenticated
  using (private.franchise_supervises_rfq(rfq_providers.rfq_id));

drop policy if exists quotes_franchise_library_read on public.quotes;
create policy quotes_franchise_library_read on public.quotes
  for select to authenticated
  using (private.franchise_supervises_quote(quotes.id));

drop policy if exists quote_versions_franchise_library_read on public.quote_versions;
create policy quote_versions_franchise_library_read on public.quote_versions
  for select to authenticated
  using (private.franchise_supervises_quote(quote_versions.quote_id));

drop policy if exists contracts_franchise_library_read on public.contracts;
create policy contracts_franchise_library_read on public.contracts
  for select to authenticated
  using (private.franchise_supervises_contract(contracts.id));

drop policy if exists missions_franchise_library_read on public.missions;
create policy missions_franchise_library_read on public.missions
  for select to authenticated
  using (private.franchise_supervises_contract(missions.contract_id));

drop policy if exists provider_services_franchise_library_read on public.provider_services;
create policy provider_services_franchise_library_read on public.provider_services
  for select to authenticated
  using (private.franchise_supervises_catalog_service(provider_services.service_id));

drop policy if exists provider_service_match_profiles_franchise_library_read on public.provider_service_match_profiles;
create policy provider_service_match_profiles_franchise_library_read on public.provider_service_match_profiles
  for select to authenticated
  using (private.franchise_supervises_catalog_service(provider_service_match_profiles.service_id));

drop policy if exists provider_capacity_versions_franchise_library_read on public.provider_capacity_versions;
create policy provider_capacity_versions_franchise_library_read on public.provider_capacity_versions
  for select to authenticated
  using (
    provider_capacity_versions.service_id is not null
    and private.franchise_supervises_catalog_service(provider_capacity_versions.service_id)
  );

drop policy if exists provider_qualifications_franchise_library_read on public.provider_qualifications;
create policy provider_qualifications_franchise_library_read on public.provider_qualifications
  for select to authenticated
  using (
    provider_qualifications.service_id is not null
    and private.franchise_supervises_catalog_service(provider_qualifications.service_id)
  );

drop policy if exists provider_document_families_franchise_library_read on public.provider_document_families;
create policy provider_document_families_franchise_library_read on public.provider_document_families
  for select to authenticated
  using (private.franchise_supervises_document_family(provider_document_families.id));

drop policy if exists provider_document_versions_franchise_library_read on public.provider_document_versions;
create policy provider_document_versions_franchise_library_read on public.provider_document_versions
  for select to authenticated
  using (private.franchise_supervises_document_version(provider_document_versions.id));

drop policy if exists internal_message_threads_franchise_library_read on public.internal_message_threads;
create policy internal_message_threads_franchise_library_read on public.internal_message_threads
  for select to authenticated
  using (private.franchise_supervises_request(internal_message_threads.service_request_id));

drop policy if exists internal_message_participants_franchise_library_read on public.internal_message_participants;
create policy internal_message_participants_franchise_library_read on public.internal_message_participants
  for select to authenticated
  using (private.franchise_supervises_thread(internal_message_participants.thread_id));

drop policy if exists internal_messages_franchise_library_read on public.internal_messages;
create policy internal_messages_franchise_library_read on public.internal_messages
  for select to authenticated
  using (private.franchise_supervises_thread(internal_messages.thread_id));

notify pgrst, 'reload schema';
