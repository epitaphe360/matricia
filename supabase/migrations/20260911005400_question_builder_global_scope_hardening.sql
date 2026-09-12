-- Preserve central AAL2 governance for every mutation of GLOBAL questions.

alter function private.assert_question_builder_payload(uuid,text,jsonb) rename to assert_question_builder_payload_v2;
create function private.assert_question_builder_payload(p_library_id uuid,p_scope text,p_payload jsonb) returns void
language plpgsql stable security definer set search_path=pg_catalog,private as $$
begin
 if p_payload is null then raise exception 'INVALID_CATALOG_QUESTION' using errcode='22023';end if;
 perform private.assert_question_builder_payload_v2(p_library_id,p_scope,p_payload);
end $$;

alter function public.duplicate_catalog_question(uuid,uuid,text,text,text,text,uuid) rename to duplicate_catalog_question_v1;
create function public.duplicate_catalog_question(p_question_id uuid,p_source_version_id uuid,p_new_question_key text,p_new_data_key text,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_identity public.question_bank_questions%rowtype;
begin
 select * into v_identity from public.question_bank_questions where id=p_question_id;
 if v_actor is null or not found or not private.has_library_permission(v_identity.library_id,'CATALOG_EDIT',v_actor)then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 if v_identity.scope='GLOBAL'then perform private.assert_catalog_central_aal2_locked(v_actor);end if;
 return public.duplicate_catalog_question_v1(p_question_id,p_source_version_id,p_new_question_key,p_new_data_key,p_change_reason,p_idempotency_key,p_correlation_id);
end $$;

alter function public.set_catalog_question_archived(uuid,integer,boolean,text,text,uuid) rename to set_catalog_question_archived_v1;
create function public.set_catalog_question_archived(p_question_id uuid,p_expected_identity_row_version integer,p_archived boolean,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_identity public.question_bank_questions%rowtype;
begin
 select * into v_identity from public.question_bank_questions where id=p_question_id;
 if v_actor is null or not found or not private.has_library_permission(v_identity.library_id,'CATALOG_EDIT',v_actor)then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 if v_identity.scope='GLOBAL'then perform private.assert_catalog_central_aal2_locked(v_actor);end if;
 return public.set_catalog_question_archived_v1(p_question_id,p_expected_identity_row_version,p_archived,p_change_reason,p_idempotency_key,p_correlation_id);
end $$;

revoke all on function private.assert_question_builder_payload_v2(uuid,text,jsonb),private.assert_question_builder_payload(uuid,text,jsonb),public.duplicate_catalog_question_v1(uuid,uuid,text,text,text,text,uuid),public.set_catalog_question_archived_v1(uuid,integer,boolean,text,text,uuid),public.duplicate_catalog_question(uuid,uuid,text,text,text,text,uuid),public.set_catalog_question_archived(uuid,integer,boolean,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.duplicate_catalog_question(uuid,uuid,text,text,text,text,uuid),public.set_catalog_question_archived(uuid,integer,boolean,text,text,uuid) to authenticated;
