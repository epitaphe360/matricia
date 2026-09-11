-- P05 hardening after independent tenant/security review.

create table public.client_compliance_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  compliance_case_id uuid not null,
  organization_id uuid not null,
  evidence_type text not null check (evidence_type in ('REGISTRATION_DOCUMENT','REPRESENTATIVE_AUTHORITY','TAX_DOCUMENT')),
  object_path text not null check (length(btrim(object_path)) between 8 and 500),
  file_sha256 text not null check (file_sha256 ~ '^[0-9a-f]{64}$'),
  review_status text not null default 'PENDING' check (review_status in ('PENDING','VERIFIED','REJECTED')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique (compliance_case_id, evidence_type, file_sha256),
  foreign key (compliance_case_id, organization_id)
    references public.client_compliance_cases(id, organization_id) on delete restrict,
  check ((review_status = 'PENDING') = (reviewed_by is null and reviewed_at is null))
);

alter table public.client_compliance_evidence enable row level security;
revoke all on public.client_compliance_evidence from public, anon, authenticated, service_role;
grant select on public.client_compliance_evidence to authenticated;
create policy client_compliance_evidence_read
on public.client_compliance_evidence for select to authenticated
using (
  private.has_org_role(organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], auth.uid())
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'], auth.uid())
);
create index client_compliance_evidence_case_review_idx
  on public.client_compliance_evidence (compliance_case_id, review_status, evidence_type);

create or replace function private.require_verified_client_compliance()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if new.status = 'VERIFIED' and old.status is distinct from 'VERIFIED' then
    if not exists (
      select 1
      from public.organization_identifiers identifier
      where identifier.organization_id = new.organization_id
        and identifier.identifier_type = 'ICE'
        and identifier.is_active
        and identifier.verification_status = 'VERIFIED'
    ) or not exists (
      select 1
      from public.organization_identifiers identifier
      where identifier.organization_id = new.organization_id
        and identifier.identifier_type = 'IF'
        and identifier.is_active
        and identifier.verification_status = 'VERIFIED'
    ) or not exists (
      select 1
      from public.organization_identifiers identifier
      where identifier.organization_id = new.organization_id
        and identifier.identifier_type = 'RC'
        and identifier.is_active
        and identifier.verification_status = 'VERIFIED'
    ) then
      raise exception 'VERIFIED_IDENTIFIERS_REQUIRED' using errcode = '55000';
    end if;
    if not exists (
      select 1 from public.client_compliance_evidence evidence
      where evidence.compliance_case_id = new.id
        and evidence.evidence_type = 'REGISTRATION_DOCUMENT'
        and evidence.review_status = 'VERIFIED'
    ) or not exists (
      select 1 from public.client_compliance_evidence evidence
      where evidence.compliance_case_id = new.id
        and evidence.evidence_type = 'REPRESENTATIVE_AUTHORITY'
        and evidence.review_status = 'VERIFIED'
    ) then
      raise exception 'VERIFIED_COMPLIANCE_EVIDENCE_REQUIRED' using errcode = '55000';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.require_verified_client_compliance()
  from public, anon, authenticated, service_role;
create trigger client_compliance_require_verified_evidence
before update of status on public.client_compliance_cases
for each row execute function private.require_verified_client_compliance();

alter function public.submit_client_compliance(uuid,text,uuid)
  rename to submit_client_compliance_internal;
revoke all on function public.submit_client_compliance_internal(uuid,text,uuid)
  from public, anon, authenticated, service_role;

create function public.submit_client_compliance(
  p_compliance_case_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'UNAUTHENTICATED' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.client_compliance_cases compliance_case
    where compliance_case.id = p_compliance_case_id
      and private.has_org_role(
        compliance_case.organization_id, array['CLIENT_OWNER','CLIENT_ADMIN'], v_actor
      )
  ) then
    raise exception 'COMPLIANCE_CASE_NOT_FOUND' using errcode = 'P0002';
  end if;
  return public.submit_client_compliance_internal(
    p_compliance_case_id, p_idempotency_key, p_correlation_id
  );
end;
$$;
revoke all on function public.submit_client_compliance(uuid,text,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.submit_client_compliance(uuid,text,uuid)
  to authenticated;

revoke select on public.client_trials from authenticated;
drop policy client_trials_read on public.client_trials;

create function public.list_my_client_trials()
returns table (
  id uuid,
  organization_id uuid,
  compliance_case_id uuid,
  effective_status text,
  trial_started_at timestamptz,
  trial_ends_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select trial.id, trial.organization_id, trial.compliance_case_id,
    case when trial.status = 'TRIAL_ACTIVE' and trial.trial_ends_at > clock_timestamp()
      then 'TRIAL_ACTIVE' else 'TRIAL_EXPIRED' end,
    trial.trial_started_at, trial.trial_ends_at
  from public.client_trials trial
  where private.has_org_role(
    trial.organization_id,
    array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_ACCOUNTING','CLIENT_MEMBER','CLIENT_VIEWER'],
    auth.uid()
  ) or private.has_platform_role(
    array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'], auth.uid()
  );
$$;
revoke all on function public.list_my_client_trials() from public, anon, authenticated, service_role;
grant execute on function public.list_my_client_trials() to authenticated;

create or replace function private.has_active_client_trial(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1 from public.client_trials trial
    where trial.organization_id = p_organization_id
      and trial.status = 'TRIAL_ACTIVE'
      and trial.trial_started_at <= clock_timestamp()
      and trial.trial_ends_at > clock_timestamp()
  );
$$;
revoke all on function private.has_active_client_trial(uuid)
  from public, anon, authenticated, service_role;

notify pgrst, 'reload schema';
