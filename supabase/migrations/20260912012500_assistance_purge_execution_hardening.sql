-- Autonomous, bounded assistance purge execution and broader privacy-first identifiers.

create or replace function private.minimize_assistance_input(p_text text) returns text language plpgsql immutable set search_path=pg_catalog as $$
declare v text;
begin
 if p_text is null then return null;end if;v:=left(btrim(p_text),1000);
 v:=regexp_replace(v,'((CIN|CNIE)[[:space:]°ºNn.:#=-]*)([[:alpha:]]{1,2}[[:space:]-]*[0-9][0-9[:space:]-]{4,10})','\1[CIN]','gi');
 v:=regexp_replace(v,'((PASSEPORT|PASSPORT)[[:space:]°ºNn.:#=-]*)([[:alpha:]]{1,2}[[:space:]-]*[0-9][0-9[:space:]-]{4,10})','\1[PASSPORT]','gi');
 v:=regexp_replace(v,'(ICE[[:space:]#:=-]*)([0-9][0-9 -]{13,20}[0-9])','\1[ICE]','gi');
 v:=regexp_replace(v,'((IF|IDENTIFIANT[[:space:]]+FISCAL)[[:space:]#:=-]*)([0-9][0-9 -]{4,12}[0-9])','\1[IF]','gi');
 v:=regexp_replace(v,'((RC|REGISTRE[[:space:]]+DE[[:space:]]+COMMERCE)[[:space:]#:=-]*)([[:alpha:]ء-ي -]{0,30}[0-9][0-9 /-]{1,18})','\1[RC]','gi');
 v:=regexp_replace(v,'(CNSS[[:space:]#:=-]*)([0-9][0-9 -]{4,15}[0-9])','\1[CNSS]','gi');
 v:=regexp_replace(v,'((NOM|NAME|CONTACT|REPRÉSENTANT|REPRÉSENTANTE|RESPONSABLE|الاسم)[[:space:]#:=-]+)([[:alpha:]ء-ي][[:alpha:]ء-ي'' -]{1,100})','\1[NAME]','gi');
 v:=regexp_replace(v,'(^|[[:space:],;])((M[.]|MME|MLLE|MR|MRS|MONSIEUR|MADAME)[[:space:]]+[[:alpha:]ء-ي][[:alpha:]ء-ي'' -]{1,80})','\1[NAME]','gi');
 v:=regexp_replace(v,'(^|[;,])([[:space:]]*[A-ZÀ-ÖØ-Þ][[:lower:]à-öø-ÿ''’-]{2,}[[:space:]]+[A-ZÀ-ÖØ-Þ][[:lower:]à-öø-ÿ''’-]{2,}([[:space:]]+[A-ZÀ-ÖØ-Þ][[:lower:]à-öø-ÿ''’-]{2,}){0,2})([;,]|$)','\1[NAME]\4','g');
 v:=regexp_replace(v,'(^|[;,])([[:space:]]*[A-ZÀ-ÖØ-Þ]{2,}[[:space:]]+[A-ZÀ-ÖØ-Þ]{2,}([[:space:]]+[A-ZÀ-ÖØ-Þ]{2,}){0,2})([;,]|$)','\1[NAME]\4','g');
 v:=regexp_replace(v,'(^|[;,،؛])([[:space:]]*[ء-ي]{2,}[[:space:]]+[ء-ي]{2,}([[:space:]]+[ء-ي]{2,}){0,2})([;,،؛]|$)','\1[NAME]\4','g');
 v:=regexp_replace(v,'(^|[^[:alnum:]])([[:alpha:]]{1,2}[[:space:]-]*[0-9][0-9[:space:]-]{4,10})([^[:alnum:]]|$)','\1[IDENTIFIER]\3','g');
 v:=regexp_replace(v,'((ADRESSE|ADDRESS|العنوان)[[:space:]#:=-]+)([^;[:cntrl:]]{3,180})','\1[ADDRESS]','gi');
 v:=regexp_replace(v,'(^|[[:space:],;])([0-9]{1,6}[[:space:]]+)?(RUE|AVENUE|AV[.]|BOULEVARD|BD[.]|QUARTIER|LOTISSEMENT|LOT|شارع|حي)[[:space:]][^;[:cntrl:]]{2,160}','\1[ADDRESS]','gi');
 v:=regexp_replace(v,'[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}','[EMAIL]','gi');v:=regexp_replace(v,'[+]?[0-9][0-9 ()-]{7,}[0-9]','[PHONE]','g');return v;
end$$;

revoke all on function private.minimize_assistance_input(text)from public,anon,authenticated,service_role;

create or replace function public.fail_assistance_input_purge_job(p_job_id uuid,p_lease_token uuid,p_worker_id text,p_idempotency_key text,p_error_code text)returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$
declare j public.assistance_input_purge_jobs%rowtype;v jsonb;v_status text;
begin
 if auth.role()<>'service_role'then raise exception'ASSISTANCE_PURGE_FORBIDDEN'using errcode='42501';end if;
 select result into v from public.assistance_input_purge_attempts where job_id=p_job_id and idempotency_key=p_idempotency_key;if found then return v;end if;
 select*into j from public.assistance_input_purge_jobs where id=p_job_id for update;
 if not found or j.status<>'CLAIMED'or j.lease_token is distinct from p_lease_token or j.worker_id is distinct from p_worker_id or j.leased_until<=clock_timestamp()then raise exception'ASSISTANCE_PURGE_LEASE_INVALID'using errcode='55000';end if;
 v_status:=case when j.attempt_count>=5 then'DEAD_LETTER'else'FAILED'end;v:=jsonb_build_object('job_id',j.id,'status',v_status,'attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64),'correlation_id',p_lease_token);
 insert into public.assistance_input_purge_attempts(job_id,attempt_number,idempotency_key,worker_id,outcome,error_code,result)values(j.id,j.attempt_count,p_idempotency_key,p_worker_id,v_status,left(coalesce(p_error_code,'UNSPECIFIED'),64),v);
 update public.assistance_input_purge_jobs set status=v_status,available_at=case when v_status='FAILED'then clock_timestamp()+make_interval(secs=>least(3600,30*(2^greatest(attempt_count-1,0))::integer))else available_at end,lease_token=null,leased_until=null,last_error_code=left(coalesce(p_error_code,'UNSPECIFIED'),64),updated_at=clock_timestamp()where id=j.id;
 insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(j.organization_id,'SYSTEM','assistance.input_purge.'||lower(v_status),'assistance_input_purge_job',j.id::text,p_lease_token,jsonb_build_object('attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64)),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(j.organization_id,'assistance_input_purge_job',j.id::text,case when v_status='FAILED'then'AssistanceInputPurgeRetryScheduled'else'AssistanceInputPurgeDeadLettered'end,p_lease_token,jsonb_build_object('job_id',j.id,'attempt_number',j.attempt_count,'error_code',left(coalesce(p_error_code,'UNSPECIFIED'),64)),'assistance-purge-'||lower(v_status)||'-'||j.id::text||'-'||j.attempt_count::text);return v;
end$$;
revoke all on function public.fail_assistance_input_purge_job(uuid,uuid,text,text,text)from public,anon,authenticated;grant execute on function public.fail_assistance_input_purge_job(uuid,uuid,text,text,text)to service_role;

create function private.run_assistance_input_purge_cycle(p_limit integer default 100)returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private as $$
declare previous_claims text:=current_setting('request.jwt.claims',true);scheduled integer:=0;processed integer:=0;c jsonb;
begin
 if p_limit<1 or p_limit>100 then raise exception'ASSISTANCE_PURGE_CYCLE_LIMIT_INVALID'using errcode='22023';end if;
 perform set_config('request.jwt.claims','{"role":"service_role"}',true);
 scheduled:=public.schedule_assistance_input_purges(clock_timestamp(),p_limit);
 for c in select*from public.claim_assistance_input_purge_jobs('db-retention-worker-v1',p_limit,300)loop perform public.complete_assistance_input_purge_job((c->>'job_id')::uuid,(c->>'lease_token')::uuid,'db-retention-worker-v1','auto-'||(c->>'job_id')||'-'||(c->>'attempt_number'));processed:=processed+1;end loop;
 perform set_config('request.jwt.claims',coalesce(previous_claims,''),true);return jsonb_build_object('scheduled',scheduled,'processed',processed,'worker_version','V1');
exception when others then perform set_config('request.jwt.claims',coalesce(previous_claims,''),true);raise;
end$$;
revoke all on function private.run_assistance_input_purge_cycle(integer)from public,anon,authenticated,service_role;

do $$begin
 if exists(select 1 from pg_available_extensions where name='pg_cron')then
  create extension if not exists pg_cron;
  perform cron.schedule('matricia-assistance-input-purge-v1','*/5 * * * *','select private.run_assistance_input_purge_cycle(100)');
 end if;
end$$;
