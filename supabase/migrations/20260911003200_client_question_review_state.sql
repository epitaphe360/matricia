-- Keep a case in remediation when one accepted response does not clear every
-- blocking anomaly. This trigger runs before the document submission gate.

create or replace function private.adjust_client_post_response_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if old.status = 'RESPONSE_RECEIVED'
     and new.status = 'UNDER_REVIEW'
     and exists (
       select 1 from public.client_administrative_anomalies anomaly
       where anomaly.compliance_case_id = new.id
         and anomaly.blocking
         and anomaly.status in ('OPEN','QUESTIONED')
     ) then
    new.status := 'DOCUMENTS_REQUIRED';
  end if;
  return new;
end;
$$;
revoke all on function private.adjust_client_post_response_state()
  from public,anon,authenticated,service_role;
drop trigger if exists client_compliance_adjust_post_response
  on public.client_compliance_cases;
create trigger client_compliance_adjust_post_response
before update of status on public.client_compliance_cases
for each row execute function private.adjust_client_post_response_state();

notify pgrst, 'reload schema';
