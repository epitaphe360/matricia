-- Additive follow-up after 20260921200000: version FKs and franchise read of
-- service-qualification decisions. Tables stay SELECT-only.

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'anomaly_definitions_current_version_fk') then
    alter table public.anomaly_definitions
      add constraint anomaly_definitions_current_version_fk
      foreign key (current_version_id) references public.anomaly_definition_versions(id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'risk_definitions_current_version_fk') then
    alter table public.risk_definitions
      add constraint risk_definitions_current_version_fk
      foreign key (current_version_id) references public.risk_definition_versions(id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'recommendation_definitions_current_version_fk') then
    alter table public.recommendation_definitions
      add constraint recommendation_definitions_current_version_fk
      foreign key (current_version_id) references public.recommendation_definition_versions(id) on delete restrict;
  end if;
end
$$;

drop policy if exists provider_qualification_decisions_franchise_library_read on public.provider_qualification_decisions;
create policy provider_qualification_decisions_franchise_library_read on public.provider_qualification_decisions
  for select to authenticated using (
    provider_qualification_decisions.service_id is not null
    and private.franchise_supervises_catalog_service(provider_qualification_decisions.service_id)
  );

notify pgrst, 'reload schema';
