-- Additive correction: every purge outcome carries a non-PII, replay-stable correlation UUID.

create or replace function public.complete_assistance_input_purge_job(p_job_id uuid,p_lease_token uuid,p_worker_id text,p_idempotency_key text) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare j public.assistance_input_purge_jobs%rowtype;v jsonb;
begin
 if auth.role()<>'service_role' then raise exception 'ASSISTANCE_PURGE_FORBIDDEN' using errcode='42501';end if;
 select result into v from public.assistance_input_purge_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return v;end if;
 select * into j from public.assistance_input_purge_jobs where id=p_job_id for update;
 if not found or j.status<>'CLAIMED'or j.lease_token is distinct from p_lease_token or j.worker_id is distinct from p_worker_id or j.leased_until<=clock_timestamp()then raise exception'ASSISTANCE_PURGE_LEASE_INVALID'using errcode='55000';end if;
 update public.assistance_requests set input_text=null,input_text_redacted_at=clock_timestamp(),input_text_expires_at=null where id=j.request_id;
 v:=jsonb_build_object('job_id',j.id,'request_id',j.request_id,'status','COMPLETED','attempt_number',j.attempt_count,'correlation_id',p_lease_token);
 insert into public.assistance_input_purge_attempts(job_id,attempt_number,idempotency_key,worker_id,outcome,result)values(j.id,j.attempt_count,p_idempotency_key,p_worker_id,'COMPLETED',v);
 update public.assistance_input_purge_jobs set status='COMPLETED',completed_at=clock_timestamp(),lease_token=null,leased_until=null,updated_at=clock_timestamp()where id=j.id;
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,'SYSTEM','assistance.input_purge.completed','assistance_input_purge_job',j.id::text,p_lease_token,jsonb_build_object('request_id',j.request_id,'attempt_number',j.attempt_count),'0000000000000000000000000000000000000000000000000000000000000000');
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'assistance_input_purge_job',j.id::text,'AssistanceInputPurged',p_lease_token,jsonb_build_object('job_id',j.id,'request_id',j.request_id,'attempt_number',j.attempt_count),'assistance-purge-completed-'||j.id::text);
 return v;
end$$;

create or replace function public.fail_assistance_input_purge_job(p_job_id uuid,p_lease_token uuid,p_worker_id text,p_idempotency_key text,p_error_code text) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public as $$
declare j public.assistance_input_purge_jobs%rowtype;v jsonb;v_status text;
begin
 if auth.role()<>'service_role' then raise exception 'ASSISTANCE_PURGE_FORBIDDEN' using errcode='42501';end if;
 select result into v from public.assistance_input_purge_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return v;end if;
 select * into j from public.assistance_input_purge_jobs where id=p_job_id for update;
 if not found or j.status<>'CLAIMED'or j.lease_token is distinct from p_lease_token or j.worker_id is distinct from p_worker_id then raise exception'ASSISTANCE_PURGE_LEASE_INVALID'using errcode='55000';end if;
 v_status:=case when j.attempt_count>=5 then'DEAD_LETTER'else'FAILED'end;
 v:=jsonb_build_object('job_id',j.id,'status',v_status,'attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64),'correlation_id',p_lease_token);
 insert into public.assistance_input_purge_attempts(job_id,attempt_number,idempotency_key,worker_id,outcome,error_code,result)values(j.id,j.attempt_count,p_idempotency_key,p_worker_id,v_status,left(coalesce(p_error_code,'UNSPECIFIED'),64),v);
 update public.assistance_input_purge_jobs set status=v_status,available_at=case when v_status='FAILED'then clock_timestamp()+make_interval(secs=>least(3600,30*(2^greatest(attempt_count-1,0))::integer))else available_at end,lease_token=null,leased_until=null,last_error_code=left(coalesce(p_error_code,'UNSPECIFIED'),64),updated_at=clock_timestamp()where id=j.id;
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,'SYSTEM','assistance.input_purge.'||lower(v_status),'assistance_input_purge_job',j.id::text,p_lease_token,jsonb_build_object('attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64)),'0000000000000000000000000000000000000000000000000000000000000000');
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'assistance_input_purge_job',j.id::text,case when v_status='FAILED'then'AssistanceInputPurgeRetryScheduled'else'AssistanceInputPurgeDeadLettered'end,p_lease_token,jsonb_build_object('job_id',j.id,'attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64)),'assistance-purge-'||lower(v_status)||'-'||j.id::text||'-'||j.attempt_count::text);
 return v;
end$$;

revoke all on function public.complete_assistance_input_purge_job(uuid,uuid,text,text),public.fail_assistance_input_purge_job(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.complete_assistance_input_purge_job(uuid,uuid,text,text),public.fail_assistance_input_purge_job(uuid,uuid,text,text,text) to service_role;
