-- Additive wrapper around the already deployed abuse commands. Rollback must only
-- occur after confirming no command is in flight; historical rows remain untouched.
create table private.abuse_command_keys(
 actor_user_id uuid not null references auth.users(id) on delete restrict,
 operation_scope text not null,
 idempotency_key text not null,
 request_hash text not null check(request_hash~'^[0-9a-f]{64}$'),
 response_body jsonb,
 created_at timestamptz not null default clock_timestamp(),
 primary key(actor_user_id,operation_scope,idempotency_key),
 check(length(idempotency_key)between 8 and 200)
);
revoke all on private.abuse_command_keys from public,anon,authenticated,service_role;

alter function public.create_abuse_rule_version(text,text,integer,integer,integer,integer,jsonb,boolean,text,uuid) rename to create_abuse_rule_version_unchecked_v1;
alter function public.decide_abuse_case(uuid,integer,text,text,text,text,uuid) rename to decide_abuse_case_unchecked_v1;
revoke all on function public.create_abuse_rule_version_unchecked_v1(text,text,integer,integer,integer,integer,jsonb,boolean,text,uuid),public.decide_abuse_case_unchecked_v1(uuid,integer,text,text,text,text,uuid) from public,anon,authenticated,service_role;

create function private.begin_abuse_command(p_actor uuid,p_scope text,p_key text,p_hash text)returns jsonb language plpgsql security definer set search_path=pg_catalog,private as $$
declare existing private.abuse_command_keys%rowtype;begin
 if p_actor is null or length(p_key)not between 8 and 200 or p_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_ABUSE_IDEMPOTENCY'using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('abuse-command:'||p_actor::text||':'||p_scope||':'||p_key,0));
 select*into existing from private.abuse_command_keys where actor_user_id=p_actor and operation_scope=p_scope and idempotency_key=p_key;
 if found then if existing.request_hash<>p_hash then raise exception'ABUSE_IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;if existing.response_body is not null then return existing.response_body;end if;raise exception'ABUSE_IDEMPOTENCY_IN_PROGRESS'using errcode='55000';end if;
 insert into private.abuse_command_keys(actor_user_id,operation_scope,idempotency_key,request_hash)values(p_actor,p_scope,p_key,p_hash);return null;
end$$;
create function private.finish_abuse_command(p_actor uuid,p_scope text,p_key text,p_response jsonb)returns void language sql security definer set search_path=pg_catalog,private as $$update private.abuse_command_keys set response_body=p_response where actor_user_id=p_actor and operation_scope=p_scope and idempotency_key=p_key and response_body is null$$;
revoke all on function private.begin_abuse_command(uuid,text,text,text),private.finish_abuse_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;

create function public.create_abuse_rule_version(p_rule_code text,p_event_type text,p_window_seconds integer,p_max_events integer,p_review_score integer,p_block_score integer,p_conditions jsonb,p_activate boolean,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;cached jsonb;scope text:='abuse.rule.create:'||coalesce(p_rule_code,'');begin
 h:=private.canonical_request_hash(jsonb_build_object('code',p_rule_code,'event',p_event_type,'window',p_window_seconds,'max',p_max_events,'review',p_review_score,'block',p_block_score,'conditions',p_conditions,'activate',p_activate));
 cached:=private.begin_abuse_command(a,scope,p_idempotency_key,h);if cached is not null then return cached;end if;
 r:=public.create_abuse_rule_version_unchecked_v1(p_rule_code,p_event_type,p_window_seconds,p_max_events,p_review_score,p_block_score,p_conditions,p_activate,p_idempotency_key,p_correlation_id);
 perform private.finish_abuse_command(a,scope,p_idempotency_key,r);return r;
end$$;

create function public.decide_abuse_case(p_case_id uuid,p_expected_row_version integer,p_decision text,p_reason text,p_evidence_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();h text;r jsonb;cached jsonb;scope text:='abuse.case.decide:'||coalesce(p_case_id::text,'');begin
 h:=private.canonical_request_hash(jsonb_build_object('case',p_case_id,'expected',p_expected_row_version,'decision',p_decision,'reason',btrim(coalesce(p_reason,'')),'evidence',p_evidence_hash));
 cached:=private.begin_abuse_command(a,scope,p_idempotency_key,h);if cached is not null then return cached;end if;
 r:=public.decide_abuse_case_unchecked_v1(p_case_id,p_expected_row_version,p_decision,p_reason,p_evidence_hash,p_idempotency_key,p_correlation_id);
 perform private.finish_abuse_command(a,scope,p_idempotency_key,r);return r;
end$$;
revoke all on function public.create_abuse_rule_version(text,text,integer,integer,integer,integer,jsonb,boolean,text,uuid),public.decide_abuse_case(uuid,integer,text,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_abuse_rule_version(text,text,integer,integer,integer,integer,jsonb,boolean,text,uuid),public.decide_abuse_case(uuid,integer,text,text,text,text,uuid) to authenticated;
