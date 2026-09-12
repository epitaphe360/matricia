-- Additive retention fix: only retained non-empty input receives an expiry.

alter table public.assistance_requests alter column input_text_expires_at drop default;

create function private.normalize_assistance_request_retention()returns trigger language plpgsql set search_path=pg_catalog,private as $$begin
 new.input_text:=private.minimize_assistance_input(new.input_text);
 if new.input_text is null or btrim(new.input_text)=''then new.input_text:=null;new.input_text_expires_at:=null;new.input_text_redacted_at:=null;
 elsif new.input_text_expires_at is null then new.input_text_expires_at:=coalesce(new.created_at,clock_timestamp())+interval'30 days';end if;
 return new;
end$$;
create trigger assistance_requests_retention_on_insert before insert on public.assistance_requests for each row execute function private.normalize_assistance_request_retention();

create or replace function private.protect_assistance_request()returns trigger language plpgsql set search_path=pg_catalog,private as $$begin
 if tg_op='DELETE'then raise exception'ASSISTANCE_REQUEST_IMMUTABLE'using errcode='55000';end if;
 new.input_text:=private.minimize_assistance_input(new.input_text);if new.input_text is null or btrim(new.input_text)=''then new.input_text:=null;new.input_text_expires_at:=null;end if;
 if(to_jsonb(new)-array['input_text','input_text_redacted_at','input_text_expires_at'])is distinct from(to_jsonb(old)-array['input_text','input_text_redacted_at','input_text_expires_at'])or not(
  (new.input_text=private.minimize_assistance_input(old.input_text)and new.input_text is not null and old.input_text_redacted_at is null and new.input_text_redacted_at is null and new.input_text_expires_at=old.created_at+interval'30 days')or
  (old.input_text is null and new.input_text is null and old.input_text_redacted_at is null and new.input_text_redacted_at is null and new.input_text_expires_at is null)or
  (new.input_text is null and old.input_text is not null and new.input_text_redacted_at is not null and new.input_text_expires_at is null)
 )then raise exception'ASSISTANCE_REQUEST_IMMUTABLE'using errcode='55000';end if;return new;
end$$;

update public.assistance_requests set input_text_expires_at=null where input_text is null and input_text_expires_at is not null;
revoke all on function private.normalize_assistance_request_retention(),private.protect_assistance_request()from public,anon,authenticated,service_role;
