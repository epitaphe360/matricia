-- V4.1 admin-managed external readiness evidence and four-eyes validation.

create table public.admin_external_validation_cases(
 id uuid primary key default extensions.gen_random_uuid(),
 validation_kind text not null check(validation_kind in('CNDP_PROCESSING_DECLARATION','CNDP_TRANSFER_AUTHORIZATION','SIGNATURE_PROVIDER_CERTIFICATION','CATALOG_ARABIC_REVIEW','CATALOG_EXPERT_REVIEW','CATALOG_OPPORTUNITY_MAPPING','RESTORE_TEST_EVIDENCE','SECURITY_PENETRATION_EVIDENCE','PRODUCTION_AUTHORIZATION')),
 target_environment text not null check(target_environment in('DEVELOPMENT','STAGING','PRODUCTION')),
 reference_code text not null check(length(btrim(reference_code))between 3 and 160),
 title text not null check(length(btrim(title))between 3 and 240),
 status text not null default'SUBMITTED'check(status in('SUBMITTED','APPROVED','REJECTED')),
 current_evidence_version integer not null default 1 check(current_evidence_version>0),
 submitted_by uuid not null references auth.users(id),reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,row_version integer not null default 1 check(row_version>0),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp()
);
create index admin_external_validation_cases_queue_idx on public.admin_external_validation_cases(status,validation_kind,created_at desc);

create table public.admin_external_validation_evidence_versions(
 id uuid primary key default extensions.gen_random_uuid(),case_id uuid not null references public.admin_external_validation_cases(id),
 version integer not null check(version>0),issuer text not null check(length(btrim(issuer))between 2 and 160),
 issued_on date not null,expires_on date,storage_reference text not null check(length(btrim(storage_reference))between 3 and 500),
 evidence_sha256 text not null check(evidence_sha256~'^[0-9a-f]{64}$'),metadata jsonb not null default'{}'::jsonb,
 submitted_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(case_id,version),
 check(expires_on is null or expires_on>=issued_on),check(jsonb_typeof(metadata)='object')
);
create table public.admin_external_validation_decisions(
 id uuid primary key default extensions.gen_random_uuid(),case_id uuid not null references public.admin_external_validation_cases(id),
 evidence_version integer not null,decision text not null check(decision in('APPROVE','REJECT')),
 reason text not null check(length(btrim(reason))between 10 and 2000),rule_version text not null check(rule_version~'^[A-Z][A-Z0-9_.-]{2,79}$'),
 decided_by uuid not null references auth.users(id),correlation_id uuid not null,decided_at timestamptz not null default clock_timestamp(),unique(case_id,evidence_version)
);

alter table public.admin_external_validation_cases enable row level security;
alter table public.admin_external_validation_evidence_versions enable row level security;
alter table public.admin_external_validation_decisions enable row level security;
create policy admin_external_validation_cases_read on public.admin_external_validation_cases for select to authenticated using(private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR']));
create policy admin_external_validation_evidence_read on public.admin_external_validation_evidence_versions for select to authenticated using(private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR']));
create policy admin_external_validation_decisions_read on public.admin_external_validation_decisions for select to authenticated using(private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR']));
create trigger admin_external_validation_evidence_immutable before update or delete on public.admin_external_validation_evidence_versions for each row execute function private.prevent_update_delete();
create trigger admin_external_validation_decisions_immutable before update or delete on public.admin_external_validation_decisions for each row execute function private.prevent_update_delete();

create function private.can_manage_external_validation(p_kind text,p_actor uuid)returns boolean language sql stable security definer set search_path=pg_catalog,private as $$
 select case when p_kind like'CATALOG_%'then private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER'],p_actor)
 when p_kind='PRODUCTION_AUTHORIZATION'then private.has_platform_role(array['SUPER_ADMIN'],p_actor)
 else private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER'],p_actor)end
$$;

create function public.submit_admin_external_validation_v41(p_validation_kind text,p_target_environment text,p_reference_code text,p_title text,p_issuer text,p_issued_on date,p_expires_on date,p_storage_reference text,p_evidence_sha256 text,p_metadata jsonb,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;c uuid;
begin
 if a is null or auth.jwt()->>'aal'is distinct from'aal2'or not private.can_manage_external_validation(p_validation_kind,a)then raise exception'EXTERNAL_VALIDATION_SUBMIT_AAL2_REQUIRED'using errcode='42501';end if;
 if p_validation_kind not in('CNDP_PROCESSING_DECLARATION','CNDP_TRANSFER_AUTHORIZATION','SIGNATURE_PROVIDER_CERTIFICATION','CATALOG_ARABIC_REVIEW','CATALOG_EXPERT_REVIEW','CATALOG_OPPORTUNITY_MAPPING','RESTORE_TEST_EVIDENCE','SECURITY_PENETRATION_EVIDENCE','PRODUCTION_AUTHORIZATION')or p_target_environment not in('DEVELOPMENT','STAGING','PRODUCTION')or length(btrim(coalesce(p_reference_code,'')))not between 3 and 160 or length(btrim(coalesce(p_title,'')))not between 3 and 240 or length(btrim(coalesce(p_issuer,'')))not between 2 and 160 or p_issued_on is null or(p_expires_on is not null and p_expires_on<p_issued_on)or length(btrim(coalesce(p_storage_reference,'')))not between 3 and 500 or coalesce(p_evidence_sha256,'')!~'^[0-9a-f]{64}$'or jsonb_typeof(p_metadata)<>'object'or private.v41_json_has_sensitive_keys(p_metadata)or(p_validation_kind='PRODUCTION_AUTHORIZATION'and p_target_environment<>'PRODUCTION')then raise exception'INVALID_EXTERNAL_VALIDATION_EVIDENCE'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('kind',p_validation_kind,'environment',p_target_environment,'reference',p_reference_code,'title',p_title,'issuer',p_issuer,'issued_on',p_issued_on,'expires_on',p_expires_on,'storage_reference',p_storage_reference,'sha256',p_evidence_sha256,'metadata',p_metadata));r:=private.begin_admin_command('v41.external_validation.submit',p_idempotency_key,h,a);if r is not null then return r;end if;
 insert into public.admin_external_validation_cases(validation_kind,target_environment,reference_code,title,submitted_by)values(p_validation_kind,p_target_environment,btrim(p_reference_code),btrim(p_title),a)returning id into c;
 insert into public.admin_external_validation_evidence_versions(case_id,version,issuer,issued_on,expires_on,storage_reference,evidence_sha256,metadata,submitted_by)values(c,1,btrim(p_issuer),p_issued_on,p_expires_on,btrim(p_storage_reference),p_evidence_sha256,p_metadata,a);
 r:=jsonb_build_object('outcome','EXTERNAL_VALIDATION_SUBMITTED','case_id',c,'status','SUBMITTED','row_version',1);insert into public.audit_events(actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(a,'USER','admin.external_validation.submitted','admin_external_validation',c::text,p_correlation_id,jsonb_build_object('kind',p_validation_kind,'environment',p_target_environment,'reference',p_reference_code,'evidence_sha256',p_evidence_sha256),repeat('0',64));insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values('admin_external_validation',c::text,'AdminExternalValidationSubmittedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_admin_command('v41.external_validation.submit',p_idempotency_key,a,r);return r;
end$$;

create function public.decide_admin_external_validation_v41(p_case_id uuid,p_decision text,p_reason text,p_rule_version text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb
language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();x public.admin_external_validation_cases%rowtype;h text;r jsonb;next_status text;
begin
 select*into x from public.admin_external_validation_cases where id=p_case_id;
 if a is null or not found or auth.jwt()->>'aal'is distinct from'aal2'or not private.can_manage_external_validation(x.validation_kind,a)or a=x.submitted_by then raise exception'EXTERNAL_VALIDATION_DECISION_DENIED'using errcode='42501';end if;
 if p_decision not in('APPROVE','REJECT')or length(btrim(coalesce(p_reason,'')))not between 10 and 2000 or coalesce(p_rule_version,'')!~'^[A-Z][A-Z0-9_.-]{2,79}$'then raise exception'INVALID_EXTERNAL_VALIDATION_DECISION'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('case_id',x.id,'decision',p_decision,'reason',p_reason,'rule_version',p_rule_version,'expected',p_expected_row_version,'evidence_version',x.current_evidence_version));r:=private.begin_admin_command('v41.external_validation.decide.'||x.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 perform pg_advisory_xact_lock(hashtextextended('external-validation:'||x.id::text,0));select*into x from public.admin_external_validation_cases where id=x.id for update;if x.status<>'SUBMITTED'or x.row_version<>p_expected_row_version then raise exception'STALE_EXTERNAL_VALIDATION'using errcode='40001';end if;
 next_status:=case p_decision when'APPROVE'then'APPROVED'else'REJECTED'end;insert into public.admin_external_validation_decisions(case_id,evidence_version,decision,reason,rule_version,decided_by,correlation_id)values(x.id,x.current_evidence_version,p_decision,btrim(p_reason),upper(p_rule_version),a,p_correlation_id);update public.admin_external_validation_cases set status=next_status,reviewed_by=a,reviewed_at=clock_timestamp(),updated_at=clock_timestamp(),row_version=row_version+1 where id=x.id and row_version=p_expected_row_version;
 r:=jsonb_build_object('outcome',case p_decision when'APPROVE'then'EXTERNAL_VALIDATION_APPROVED'else'EXTERNAL_VALIDATION_REJECTED'end,'case_id',x.id,'status',next_status,'row_version',x.row_version+1);insert into public.audit_events(actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(a,'USER','admin.external_validation.decided','admin_external_validation',x.id::text,p_correlation_id,jsonb_build_object('kind',x.validation_kind,'decision',p_decision,'reason',p_reason,'rule_version',p_rule_version),repeat('0',64));insert into public.event_outbox(aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values('admin_external_validation',x.id::text,case p_decision when'APPROVE'then'AdminExternalValidationApprovedV1'else'AdminExternalValidationRejectedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_admin_command('v41.external_validation.decide.'||x.id::text,p_idempotency_key,a,r);return r;
end$$;

create function public.list_admin_external_validations_v41(p_limit integer default 100)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare a uuid:=auth.uid();r jsonb;
begin
 if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR'],a)then raise exception'EXTERNAL_VALIDATION_LIST_DENIED'using errcode='42501';end if;if p_limit not between 1 and 100 then raise exception'EXTERNAL_VALIDATION_LIMIT_INVALID'using errcode='22023';end if;
 select jsonb_build_object('generated_at',clock_timestamp(),'capabilities',jsonb_build_object('can_submit',private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','LIBRARY_MANAGER'],a),'can_approve',private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','LIBRARY_MANAGER'],a),'is_super_admin',private.has_platform_role(array['SUPER_ADMIN'],a)),'checklist',(select jsonb_agg(jsonb_build_object('kind',k,'approved',exists(select 1 from public.admin_external_validation_cases c where c.validation_kind=k and c.status='APPROVED'))order by k)from unnest(array['CNDP_PROCESSING_DECLARATION','CNDP_TRANSFER_AUTHORIZATION','SIGNATURE_PROVIDER_CERTIFICATION','CATALOG_ARABIC_REVIEW','CATALOG_EXPERT_REVIEW','CATALOG_OPPORTUNITY_MAPPING','RESTORE_TEST_EVIDENCE','SECURITY_PENETRATION_EVIDENCE','PRODUCTION_AUTHORIZATION'])k),'cases',coalesce((select jsonb_agg(jsonb_build_object('id',q.id,'kind',q.validation_kind,'environment',q.target_environment,'reference_code',q.reference_code,'title',q.title,'status',q.status,'row_version',q.row_version,'submitted_by',q.submitted_by,'reviewed_by',q.reviewed_by,'created_at',q.created_at,'issuer',e.issuer,'issued_on',e.issued_on,'expires_on',e.expires_on,'storage_reference',e.storage_reference,'evidence_sha256',e.evidence_sha256,'metadata',e.metadata)order by case q.status when'SUBMITTED'then 0 when'REJECTED'then 1 else 2 end,q.created_at desc)from(select*from public.admin_external_validation_cases order by created_at desc limit p_limit)q join public.admin_external_validation_evidence_versions e on e.case_id=q.id and e.version=q.current_evidence_version),'[]'::jsonb))into r;return r;
end$$;

revoke all on public.admin_external_validation_cases,public.admin_external_validation_evidence_versions,public.admin_external_validation_decisions from public,anon,authenticated,service_role;
grant select on public.admin_external_validation_cases,public.admin_external_validation_evidence_versions,public.admin_external_validation_decisions to authenticated;
revoke all on function private.can_manage_external_validation(text,uuid)from public,anon,authenticated,service_role;
revoke all on function public.submit_admin_external_validation_v41(text,text,text,text,text,date,date,text,text,jsonb,text,uuid),public.decide_admin_external_validation_v41(uuid,text,text,text,integer,text,uuid),public.list_admin_external_validations_v41(integer)from public,anon,authenticated,service_role;
grant execute on function public.submit_admin_external_validation_v41(text,text,text,text,text,date,date,text,text,jsonb,text,uuid),public.decide_admin_external_validation_v41(uuid,text,text,text,integer,text,uuid),public.list_admin_external_validations_v41(integer)to authenticated;
