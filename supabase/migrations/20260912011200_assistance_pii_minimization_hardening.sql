-- Additive P2 privacy hardening: deterministic minimisation of Moroccan identifiers, names and addresses.

create or replace function private.minimize_assistance_input(p_text text)returns text language plpgsql immutable set search_path=pg_catalog as $$declare v text;begin
 if p_text is null then return null;end if;v:=left(btrim(p_text),1000);
 -- Apply labelled identifiers before generic numeric patterns so evidence stays category-explicit.
 v:=regexp_replace(v,'(ICE[[:space:]#:=-]*)([0-9][0-9 -]{13,20}[0-9])','\1[ICE]','gi');
 v:=regexp_replace(v,'((IF|IDENTIFIANT[[:space:]]+FISCAL)[[:space:]#:=-]*)([0-9][0-9 -]{4,12}[0-9])','\1[IF]','gi');
 v:=regexp_replace(v,'((RC|REGISTRE[[:space:]]+DE[[:space:]]+COMMERCE)[[:space:]#:=-]*)([[:alpha:]ء-ي -]{0,30}[0-9][0-9 /-]{1,18})','\1[RC]','gi');
 v:=regexp_replace(v,'(CNSS[[:space:]#:=-]*)([0-9][0-9 -]{4,15}[0-9])','\1[CNSS]','gi');
 -- Labelled names and common honorific forms. Values stop at structured punctuation.
 v:=regexp_replace(v,'((NOM|NAME|CONTACT|REPRÉSENTANT|REPRÉSENTANTE|RESPONSABLE|الاسم)[[:space:]#:=-]+)([[:alpha:]ء-ي][[:alpha:]ء-ي'' -]{1,100})','\1[NAME]','gi');
 v:=regexp_replace(v,'(^|[[:space:],;])((M[.]|MME|MLLE|MR|MRS|MONSIEUR|MADAME)[[:space:]]+[[:alpha:]ء-ي][[:alpha:]ء-ي'' -]{1,80})','\1[NAME]','gi');
 -- Labelled or street-shaped postal addresses, including Arabic street/district markers.
 v:=regexp_replace(v,'((ADRESSE|ADDRESS|العنوان)[[:space:]#:=-]+)([^;[:cntrl:]]{3,180})','\1[ADDRESS]','gi');
 v:=regexp_replace(v,'(^|[[:space:],;])([0-9]{1,6}[[:space:]]+)?(RUE|AVENUE|AV[.]|BOULEVARD|BD[.]|QUARTIER|LOTISSEMENT|LOT|شارع|حي)[[:space:]][^;[:cntrl:]]{2,160}','\1[ADDRESS]','gi');
 -- Email and telephone are retained as type markers only.
 v:=regexp_replace(v,'[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}','[EMAIL]','gi');
 v:=regexp_replace(v,'[+]?[0-9][0-9 ()-]{7,}[0-9]','[PHONE]','g');
 return v;
end$$;

do $$declare q record;c uuid;masked text;begin
 for q in select id,organization_id,input_text,input_text_expires_at,created_at from public.assistance_requests where input_text is not null and input_text_redacted_at is null loop
  masked:=private.minimize_assistance_input(q.input_text);if masked is distinct from q.input_text then c:=extensions.gen_random_uuid();update public.assistance_requests set input_text=masked,input_text_expires_at=q.created_at+interval'30 days'where id=q.id;insert into public.audit_events(organization_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(q.organization_id,'SYSTEM','assistance.input.reminimized','assistance_request',q.id::text,c,jsonb_build_object('policy_version','PII_MINIMIZATION_V2'),'0000000000000000000000000000000000000000000000000000000000000000');insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(q.organization_id,'assistance_request',q.id::text,'AssistanceInputReminimizedV2',c,jsonb_build_object('request_id',q.id,'policy_version','PII_MINIMIZATION_V2'),'pii-v2-'||q.id::text);end if;
 end loop;
end$$;

revoke all on function private.minimize_assistance_input(text)from public,anon,authenticated,service_role;
