-- Additive public contact intake. Rollback: revoke execute, drop function, then drop table
-- only after exporting unresolved requests. This migration never mutates existing records.
create table public.public_contact_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  category text not null check (category in ('CLIENT','PROVIDER','FRANCHISE','OTHER')),
  reply_email text not null check (reply_email = lower(reply_email) and length(reply_email) between 5 and 254),
  message text not null check (length(message) between 20 and 4000),
  locale text not null check (locale in ('fr','ar')),
  source_path text not null check (source_path in ('/fr/contact','/ar/contact')),
  ip_hash text not null check (ip_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'RECEIVED' check (status in ('RECEIVED','IN_REVIEW','CLOSED')),
  received_at timestamptz not null default clock_timestamp()
);

alter table public.public_contact_requests enable row level security;
revoke all on public.public_contact_requests from public, anon, authenticated;
create index public_contact_requests_review_idx on public.public_contact_requests(status, received_at);
create index public_contact_requests_rate_idx on public.public_contact_requests(ip_hash, received_at desc);

create function public.submit_public_contact_request(
  p_category text,
  p_reply_email text,
  p_message text,
  p_locale text,
  p_source_path text,
  p_ip_hash text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  request_id uuid;
  normalized_email text := lower(btrim(coalesce(p_reply_email, '')));
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'CONTACT_SUBMISSION_DENIED' using errcode = '42501';
  end if;
  if p_category not in ('CLIENT','PROVIDER','FRANCHISE','OTHER')
     or p_locale not in ('fr','ar')
     or p_source_path <> '/' || p_locale || '/contact'
     or normalized_email !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
     or length(normalized_email) > 254
     or length(btrim(coalesce(p_message, ''))) not between 20 and 4000
     or p_ip_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'CONTACT_SUBMISSION_INVALID' using errcode = '22023';
  end if;
  -- Serialize every bucket before checking its count. All callers use the same
  -- IP-then-email order, preventing parallel threshold bypass and deadlocks.
  perform pg_advisory_xact_lock(hashtextextended('public-contact:ip:' || p_ip_hash, 0));
  perform pg_advisory_xact_lock(hashtextextended('public-contact:email:' || normalized_email, 0));
  if (select count(*) from public.public_contact_requests where ip_hash = p_ip_hash and received_at > clock_timestamp() - interval '1 hour') >= 5
     or (select count(*) from public.public_contact_requests where reply_email = normalized_email and received_at > clock_timestamp() - interval '1 day') >= 3 then
    raise exception 'CONTACT_SUBMISSION_RATE_LIMITED' using errcode = 'P0001';
  end if;
  insert into public.public_contact_requests(category, reply_email, message, locale, source_path, ip_hash)
  values (p_category, normalized_email, btrim(p_message), p_locale, p_source_path, p_ip_hash)
  returning id into request_id;
  return request_id;
end;
$$;

revoke all on function public.submit_public_contact_request(text,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.submit_public_contact_request(text,text,text,text,text,text) to service_role;
