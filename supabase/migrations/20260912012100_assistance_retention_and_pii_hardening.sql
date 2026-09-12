-- Privacy-first assistance retention: broader deterministic minimisation and a bounded service worker queue.

create or replace function private.minimize_assistance_input(p_text text) returns text
language plpgsql immutable set search_path=pg_catalog as $$
declare v text;
begin
 if p_text is null then return null; end if;
 v:=left(btrim(p_text),1000);
 v:=regexp_replace(v,'((CIN|CNIE)[[:space:]#:=-]*)([[:alpha:]]{1,2}[0-9]{5,8})','\1[CIN]','gi');
 v:=regexp_replace(v,'((PASSEPORT|PASSPORT)[[:space:]#:=-]*)([[:alpha:]]{1,2}[0-9]{5,8})','\1[PASSPORT]','gi');
 v:=regexp_replace(v,'(ICE[[:space:]#:=-]*)([0-9][0-9 -]{13,20}[0-9])','\1[ICE]','gi');
 v:=regexp_replace(v,'((IF|IDENTIFIANT[[:space:]]+FISCAL)[[:space:]#:=-]*)([0-9][0-9 -]{4,12}[0-9])','\1[IF]','gi');
 v:=regexp_replace(v,'((RC|REGISTRE[[:space:]]+DE[[:space:]]+COMMERCE)[[:space:]#:=-]*)([[:alpha:]ء-ي -]{0,30}[0-9][0-9 /-]{1,18})','\1[RC]','gi');
 v:=regexp_replace(v,'(CNSS[[:space:]#:=-]*)([0-9][0-9 -]{4,15}[0-9])','\1[CNSS]','gi');
 v:=regexp_replace(v,'((NOM|NAME|CONTACT|REPRÉSENTANT|REPRÉSENTANTE|RESPONSABLE|الاسم)[[:space:]#:=-]+)([[:alpha:]ء-ي][[:alpha:]ء-ي'' -]{1,100})','\1[NAME]','gi');
 v:=regexp_replace(v,'(^|[[:space:],;])((M[.]|MME|MLLE|MR|MRS|MONSIEUR|MADAME)[[:space:]]+[[:alpha:]ء-ي][[:alpha:]ء-ي'' -]{1,80})','\1[NAME]','gi');
 -- Privacy-first heuristics for otherwise unlabelled FR/AR full names in delimited fields.
 v:=regexp_replace(v,'(^|[;,])([[:space:]]*[A-ZÀ-ÖØ-Þ][[:lower:]à-öø-ÿ''’-]{2,}[[:space:]]+[A-ZÀ-ÖØ-Þ][[:lower:]à-öø-ÿ''’-]{2,}([[:space:]]+[A-ZÀ-ÖØ-Þ][[:lower:]à-öø-ÿ''’-]{2,}){0,2})([;,]|$)','\1[NAME]\4','g');
 v:=regexp_replace(v,'(^|[;,،؛])([[:space:]]*[ء-ي]{2,}[[:space:]]+[ء-ي]{2,}([[:space:]]+[ء-ي]{2,}){0,2})([;,،؛]|$)','\1[NAME]\4','g');
 -- Unlabelled Moroccan-style identity tokens are not retained verbatim.
 v:=regexp_replace(v,'(^|[^[:alnum:]])([[:alpha:]]{1,2}[0-9]{5,8})([^[:alnum:]]|$)','\1[IDENTIFIER]\3','g');
 v:=regexp_replace(v,'((ADRESSE|ADDRESS|العنوان)[[:space:]#:=-]+)([^;[:cntrl:]]{3,180})','\1[ADDRESS]','gi');
 v:=regexp_replace(v,'(^|[[:space:],;])([0-9]{1,6}[[:space:]]+)?(RUE|AVENUE|AV[.]|BOULEVARD|BD[.]|QUARTIER|LOTISSEMENT|LOT|شارع|حي)[[:space:]][^;[:cntrl:]]{2,160}','\1[ADDRESS]','gi');
 v:=regexp_replace(v,'[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}','[EMAIL]','gi');
 v:=regexp_replace(v,'[+]?[0-9][0-9 ()-]{7,}[0-9]','[PHONE]','g');
 return v;
end$$;
revoke all on function private.minimize_assistance_input(text) from public,anon,authenticated,service_role;

create table public.assistance_input_purge_jobs(
 id uuid primary key default extensions.gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 request_id uuid not null unique references public.assistance_requests(id), status text not null default 'QUEUED' check(status in('QUEUED','CLAIMED','FAILED','COMPLETED','DEAD_LETTER')),
 attempt_count integer not null default 0 check(attempt_count between 0 and 5), available_at timestamptz not null default clock_timestamp(),
 lease_token uuid,worker_id text,leased_until timestamptz,last_error_code text,completed_at timestamptz,created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp()
);
create index assistance_input_purge_jobs_dispatch_idx on public.assistance_input_purge_jobs(status,available_at,created_at) where status in('QUEUED','FAILED','CLAIMED');
create table public.assistance_input_purge_attempts(
 id uuid primary key default extensions.gen_random_uuid(),job_id uuid not null references public.assistance_input_purge_jobs(id),attempt_number integer not null,
 idempotency_key text not null,worker_id text not null,outcome text not null check(outcome in('COMPLETED','FAILED','DEAD_LETTER')),
 error_code text,result jsonb not null,created_at timestamptz not null default clock_timestamp(),unique(job_id,attempt_number),unique(job_id,idempotency_key)
);
alter table public.assistance_input_purge_jobs enable row level security;
alter table public.assistance_input_purge_jobs force row level security;
alter table public.assistance_input_purge_attempts enable row level security;
alter table public.assistance_input_purge_attempts force row level security;
revoke all on public.assistance_input_purge_jobs,public.assistance_input_purge_attempts from public,anon,authenticated,service_role;

create function public.schedule_assistance_input_purges(p_as_of timestamptz default clock_timestamp(),p_limit integer default 500) returns integer
language plpgsql security definer set search_path=pg_catalog,public,extensions as $$
declare r record;v_id uuid;v_count integer:=0;v_correlation uuid;
begin
 if auth.role()<>'service_role' then raise exception 'ASSISTANCE_PURGE_FORBIDDEN' using errcode='42501';end if;
 if p_limit<1 or p_limit>1000 then raise exception 'ASSISTANCE_PURGE_LIMIT_INVALID' using errcode='22023';end if;
 for r in select id,organization_id from public.assistance_requests where input_text is not null and input_text_redacted_at is null and input_text_expires_at<=p_as_of order by input_text_expires_at,id limit p_limit loop
  v_id:=null;insert into public.assistance_input_purge_jobs(organization_id,request_id)values(r.organization_id,r.id)on conflict(request_id)do nothing returning id into v_id;
  if v_id is not null then v_count:=v_count+1;v_correlation:=extensions.gen_random_uuid();
   insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(r.organization_id,'SYSTEM','assistance.input_purge.queued','assistance_input_purge_job',v_id::text,v_correlation,jsonb_build_object('request_id',r.id,'policy_version','PII_RETENTION_V3'),'0000000000000000000000000000000000000000000000000000000000000000');
   insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(r.organization_id,'assistance_input_purge_job',v_id::text,'AssistanceInputPurgeQueued',v_correlation,jsonb_build_object('job_id',v_id,'request_id',r.id,'policy_version','PII_RETENTION_V3'),'assistance-purge-queued-'||r.id::text);
  end if;
 end loop;return v_count;
end$$;

create function public.claim_assistance_input_purge_jobs(p_worker_id text,p_limit integer default 50,p_lease_seconds integer default 300) returns setof jsonb
language plpgsql security definer set search_path=pg_catalog,public,extensions as $$
begin
 if auth.role()<>'service_role' then raise exception 'ASSISTANCE_PURGE_FORBIDDEN' using errcode='42501';end if;
 if nullif(btrim(p_worker_id),'')is null or p_limit<1 or p_limit>100 or p_lease_seconds<30 or p_lease_seconds>900 then raise exception 'ASSISTANCE_PURGE_CLAIM_INVALID' using errcode='22023';end if;
 return query with picked as(select id from public.assistance_input_purge_jobs where attempt_count<5 and ((status in('QUEUED','FAILED')and available_at<=clock_timestamp())or(status='CLAIMED'and leased_until<=clock_timestamp()))order by available_at,created_at for update skip locked limit p_limit),u as(update public.assistance_input_purge_jobs j set status='CLAIMED',attempt_count=attempt_count+1,lease_token=extensions.gen_random_uuid(),worker_id=p_worker_id,leased_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),updated_at=clock_timestamp()from picked where j.id=picked.id returning j.*)select jsonb_build_object('job_id',id,'request_id',request_id,'organization_id',organization_id,'attempt_number',attempt_count,'lease_token',lease_token,'leased_until',leased_until)from u;
end$$;

create function public.complete_assistance_input_purge_job(p_job_id uuid,p_lease_token uuid,p_worker_id text,p_idempotency_key text) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare j public.assistance_input_purge_jobs%rowtype;v jsonb;
begin
 if auth.role()<>'service_role' then raise exception 'ASSISTANCE_PURGE_FORBIDDEN' using errcode='42501';end if;
 select result into v from public.assistance_input_purge_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return v;end if;
 select * into j from public.assistance_input_purge_jobs where id=p_job_id for update;
 if not found or j.status<>'CLAIMED'or j.lease_token is distinct from p_lease_token or j.worker_id is distinct from p_worker_id or j.leased_until<=clock_timestamp()then raise exception'ASSISTANCE_PURGE_LEASE_INVALID'using errcode='55000';end if;
 update public.assistance_requests set input_text=null,input_text_redacted_at=clock_timestamp(),input_text_expires_at=null where id=j.request_id;
 v:=jsonb_build_object('job_id',j.id,'request_id',j.request_id,'status','COMPLETED','attempt_number',j.attempt_count);
 insert into public.assistance_input_purge_attempts(job_id,attempt_number,idempotency_key,worker_id,outcome,result)values(j.id,j.attempt_count,p_idempotency_key,p_worker_id,'COMPLETED',v);
 update public.assistance_input_purge_jobs set status='COMPLETED',completed_at=clock_timestamp(),lease_token=null,leased_until=null,updated_at=clock_timestamp()where id=j.id;
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,metadata,event_hash)values(j.organization_id,'SYSTEM','assistance.input_purge.completed','assistance_input_purge_job',j.id::text,jsonb_build_object('request_id',j.request_id,'attempt_number',j.attempt_count),'0000000000000000000000000000000000000000000000000000000000000000');
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,payload,idempotency_key)values(j.organization_id,'assistance_input_purge_job',j.id::text,'AssistanceInputPurged',jsonb_build_object('job_id',j.id,'request_id',j.request_id,'attempt_number',j.attempt_count),'assistance-purge-completed-'||j.id::text);
 return v;
end$$;

create function public.fail_assistance_input_purge_job(p_job_id uuid,p_lease_token uuid,p_worker_id text,p_idempotency_key text,p_error_code text) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare j public.assistance_input_purge_jobs%rowtype;v jsonb;v_status text;
begin
 if auth.role()<>'service_role' then raise exception 'ASSISTANCE_PURGE_FORBIDDEN' using errcode='42501';end if;
 select result into v from public.assistance_input_purge_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return v;end if;
 select * into j from public.assistance_input_purge_jobs where id=p_job_id for update;
 if not found or j.status<>'CLAIMED'or j.lease_token is distinct from p_lease_token or j.worker_id is distinct from p_worker_id then raise exception'ASSISTANCE_PURGE_LEASE_INVALID'using errcode='55000';end if;
 v_status:=case when j.attempt_count>=5 then'DEAD_LETTER'else'FAILED'end;v:=jsonb_build_object('job_id',j.id,'status',v_status,'attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64));
 insert into public.assistance_input_purge_attempts(job_id,attempt_number,idempotency_key,worker_id,outcome,error_code,result)values(j.id,j.attempt_count,p_idempotency_key,p_worker_id,v_status,left(coalesce(p_error_code,'UNSPECIFIED'),64),v);
 update public.assistance_input_purge_jobs set status=v_status,available_at=case when v_status='FAILED'then clock_timestamp()+make_interval(secs=>least(3600,30*(2^greatest(attempt_count-1,0))::integer))else available_at end,lease_token=null,leased_until=null,last_error_code=left(coalesce(p_error_code,'UNSPECIFIED'),64),updated_at=clock_timestamp()where id=j.id;return v;
end$$;

revoke all on function public.schedule_assistance_input_purges(timestamptz,integer),public.claim_assistance_input_purge_jobs(text,integer,integer),public.complete_assistance_input_purge_job(uuid,uuid,text,text),public.fail_assistance_input_purge_job(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.schedule_assistance_input_purges(timestamptz,integer),public.claim_assistance_input_purge_jobs(text,integer,integer),public.complete_assistance_input_purge_job(uuid,uuid,text,text),public.fail_assistance_input_purge_job(uuid,uuid,text,text,text) to service_role;
