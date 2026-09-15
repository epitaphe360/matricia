-- Persist a guided public need as an immutable, tenant-scoped intake.
-- Rollback: revoke the RPC and archive the table; retained intake history is not deleted.
create table public.public_need_intakes (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  locale text not null check(locale in('fr','ar')),
  need_text text not null check(length(btrim(need_text)) between 10 and 1200),
  location_text text not null default '' check(length(location_text)<=1200),
  timing_text text not null default '' check(length(timing_text)<=1200),
  constraints_text text not null default '' check(length(constraints_text)<=1200),
  status text not null default 'DRAFT_REVIEW' check(status='DRAFT_REVIEW'),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,content_hash)
);
create index public_need_intakes_org_created_idx on public.public_need_intakes(organization_id,created_at desc,id desc);

create function private.prevent_public_need_intake_mutation() returns trigger
language plpgsql set search_path=pg_catalog,public,private as $$begin
  raise exception 'PUBLIC_NEED_INTAKE_IMMUTABLE' using errcode='55000';
end$$;
create trigger public_need_intakes_immutable before update or delete on public.public_need_intakes for each row execute function private.prevent_public_need_intake_mutation();
revoke all on function private.prevent_public_need_intake_mutation() from public,anon,authenticated,service_role;

alter table public.public_need_intakes enable row level security;
create policy public_need_intakes_client_read on public.public_need_intakes for select to authenticated
using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER']));
revoke all on public.public_need_intakes from public,anon,authenticated,service_role;
grant select on public.public_need_intakes to authenticated;

create function public.save_public_need_intake(
  p_organization_id uuid,
  p_payload jsonb,
  p_locale text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  actor uuid:=auth.uid();
  v_hash text;
  v_existing public.public_need_intakes%rowtype;
  v_id uuid;
  v_response jsonb;
begin
  if actor is null or not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],actor) then
    raise exception 'PUBLIC_NEED_INTAKE_DENIED' using errcode='42501';
  end if;
  if p_locale not in('fr','ar') or p_idempotency_key!~'^[0-9a-f]{64}$' or jsonb_typeof(p_payload)<>'object'
     or (select count(*) from jsonb_object_keys(p_payload))<>4 or pg_column_size(p_payload)>6000
     or length(btrim(coalesce(p_payload->>'need',''))) not between 10 and 1200
     or length(coalesce(p_payload->>'location',''))>1200
     or length(coalesce(p_payload->>'timing',''))>1200
     or length(coalesce(p_payload->>'constraints',''))>1200
     or exists(select 1 from jsonb_object_keys(p_payload) key where key not in('need','location','timing','constraints')) then
    raise exception 'INVALID_PUBLIC_NEED_INTAKE' using errcode='22023';
  end if;
  v_hash:=encode(extensions.digest(convert_to(jsonb_build_object('version','PUBLIC_NEED_V1','organization_id',p_organization_id,'payload',p_payload)::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended('public-need-intake:'||p_organization_id::text||':'||v_hash,0));
  select * into v_existing from public.public_need_intakes intake where intake.organization_id=p_organization_id and intake.content_hash=v_hash;
  if found then return jsonb_build_object('outcome','PUBLIC_NEED_INTAKE_SAVED','intake_id',v_existing.id,'status',v_existing.status,'replayed',true); end if;
  insert into public.public_need_intakes(organization_id,created_by,locale,need_text,location_text,timing_text,constraints_text,content_hash)
  values(p_organization_id,actor,p_locale,btrim(p_payload->>'need'),btrim(p_payload->>'location'),btrim(p_payload->>'timing'),btrim(p_payload->>'constraints'),v_hash)
  returning id into v_id;
  v_response:=jsonb_build_object('outcome','PUBLIC_NEED_INTAKE_SAVED','intake_id',v_id,'status','DRAFT_REVIEW','replayed',false);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(p_organization_id,actor,'USER','public_need.intake.saved','public_need_intake',v_id::text,p_correlation_id,jsonb_build_object('content_hash',v_hash,'source','PUBLIC_GUIDED_NEED'),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(p_organization_id,'public_need_intake',v_id::text,'PublicNeedIntakeSavedV1',p_correlation_id,v_response,'public-need-intake:'||v_hash);
  return v_response;
end$$;
revoke all on function public.save_public_need_intake(uuid,jsonb,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.save_public_need_intake(uuid,jsonb,text,text,uuid) to authenticated;
