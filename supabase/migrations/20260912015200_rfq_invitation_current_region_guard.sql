-- MAT-FUNC-018/020/067: every invitation revalidates current eligibility and region.
create or replace function private.enforce_rfq_invitation_current_eligibility() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare request_row public.service_requests%rowtype;request_version public.service_request_versions%rowtype;rfq_row public.rfqs%rowtype;
begin
 select * into rfq_row from public.rfqs where id=new.rfq_id;
 select * into request_row from public.service_requests where id=rfq_row.request_id;
 select * into request_version from public.service_request_versions where id=request_row.current_version_id and request_id=request_row.id;
 if rfq_row.id is null or request_row.id is null or request_version.id is null
  or coalesce((rfq_row.confidentiality_settings->>'mask_direct_contacts')::boolean,false) is not true
  or new.provider_organization_id=request_row.client_organization_id
  or not exists(
   select 1
   from public.matching_candidates candidate
   join public.provider_match_profiles profile on profile.provider_organization_id=candidate.provider_organization_id
   join public.provider_service_match_profiles service_profile on service_profile.provider_organization_id=candidate.provider_organization_id and service_profile.service_id=request_row.service_id
   join public.organizations organization on organization.id=candidate.provider_organization_id
   where candidate.id=new.matching_candidate_id
    and candidate.matching_run_id=rfq_row.matching_run_id
    and candidate.provider_organization_id=new.provider_organization_id
    and candidate.eligible
    and organization.status='ACTIVE'
    and profile.company_verified and profile.documents_valid
    and profile.financial_status='OK'and profile.quality_status='OK'
    and profile.capacity_status in('AVAILABLE','LIMITED')
    and profile.partner_contract_signed
    and service_profile.qualification_status='APPROVED'
    and service_profile.required_certifications_valid
    and coalesce(request_version.required_quote_data->>'region_code','')=any(profile.region_codes)
  )then raise exception 'RFQ_PROVIDER_NOT_CURRENTLY_ELIGIBLE' using errcode='23514';
 end if;
 return new;
end$$;
revoke all on function private.enforce_rfq_invitation_current_eligibility() from public,anon,authenticated,service_role;
drop trigger if exists rfq_provider_current_eligibility_guard on public.rfq_providers;
create trigger rfq_provider_current_eligibility_guard before insert on public.rfq_providers for each row execute function private.enforce_rfq_invitation_current_eligibility();
notify pgrst,'reload schema';
