-- Additive reconciliation: 029 was already applied to development before its
-- final submission-gate review landed. Drop/recreate keeps clean replay safe.

create or replace function private.require_client_documents_for_review()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_required_type text;
begin
  if new.status = 'UNDER_REVIEW' and old.status is distinct from 'UNDER_REVIEW' then
    foreach v_required_type in array array['REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY'] loop
      if not exists (
        select 1 from public.client_compliance_documents document
        where document.compliance_case_id = new.id
          and document.document_type = v_required_type
          and document.status in ('PENDING_REVIEW','VERIFIED')
          and (document.expires_on is null or document.expires_on >= current_date)
      ) and not exists (
        select 1 from public.client_compliance_evidence evidence
        where evidence.compliance_case_id = new.id
          and evidence.evidence_type = v_required_type
          and evidence.review_status = 'VERIFIED'
      ) then
        raise exception 'REQUIRED_CLIENT_DOCUMENTS_MISSING' using errcode='55000';
      end if;
    end loop;
  end if;
  return new;
end;
$$;
revoke all on function private.require_client_documents_for_review()
  from public,anon,authenticated,service_role;
drop trigger if exists client_compliance_require_documents_for_review
  on public.client_compliance_cases;
create trigger client_compliance_require_documents_for_review
before update of status on public.client_compliance_cases
for each row execute function private.require_client_documents_for_review();

notify pgrst, 'reload schema';
