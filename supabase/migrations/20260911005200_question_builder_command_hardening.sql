-- Normalize an omitted structured schema and fail closed when an archived identity
-- still owns a published pointer. Both changes are additive compatibility guards.

alter function private.assert_question_builder_payload(uuid,text,jsonb) rename to assert_question_builder_payload_v1;

create function private.assert_question_builder_payload(p_library_id uuid,p_scope text,p_payload jsonb) returns void
language plpgsql stable security definer set search_path=pg_catalog,private as $$
begin
 perform private.assert_question_builder_payload_v1(p_library_id,p_scope,case when p_payload?'structured_schema' then p_payload else p_payload||'{"structured_schema":null}'::jsonb end);
end $$;

create function private.guard_question_archive_published_pointer() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
begin
 if new.status='ARCHIVED' and old.status<>'ARCHIVED' and old.current_published_version_id is not null then raise exception 'CATALOG_QUESTION_ARCHIVE_REQUIRES_RELEASE' using errcode='55000';end if;
 return new;
end $$;

create trigger question_archive_published_pointer_guard before update on public.question_bank_questions for each row execute function private.guard_question_archive_published_pointer();

revoke all on function private.assert_question_builder_payload_v1(uuid,text,jsonb),private.assert_question_builder_payload(uuid,text,jsonb),private.guard_question_archive_published_pointer() from public,anon,authenticated,service_role;
