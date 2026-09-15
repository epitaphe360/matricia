-- Persist the limited public prediagnostic as an explicitly indicative,
-- immutable projection. It never masquerades as a questionnaire diagnostic.
-- Rollback: revoke the RPC, then archive the table; do not delete saved history.

create table public.public_diagnostic_intakes (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  projection_version text not null default 'PUBLIC_INTAKE_V1' check(projection_version='PUBLIC_INTAKE_V1'),
  policy_version text not null default 'PUBLIC_PRIORITY_V1' check(policy_version='PUBLIC_PRIORITY_V1'),
  locale text not null check(locale in('fr','ar')),
  answers jsonb not null check(jsonb_typeof(answers)='object' and pg_column_size(answers)<=8192),
  priorities jsonb not null check(jsonb_typeof(priorities)='array' and jsonb_array_length(priorities)<=3),
  status text not null default 'INDICATIVE' check(status='INDICATIVE'),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,content_hash)
);
create index public_diagnostic_intakes_org_created_idx on public.public_diagnostic_intakes(organization_id,created_at desc,id desc);

create function private.prevent_public_diagnostic_intake_mutation() returns trigger
language plpgsql set search_path=pg_catalog,public,private as $$begin
  raise exception 'PUBLIC_DIAGNOSTIC_INTAKE_IMMUTABLE' using errcode='55000';
end$$;
create trigger public_diagnostic_intakes_immutable before update or delete on public.public_diagnostic_intakes for each row execute function private.prevent_public_diagnostic_intake_mutation();
revoke all on function private.prevent_public_diagnostic_intake_mutation() from public,anon,authenticated,service_role;

alter table public.public_diagnostic_intakes enable row level security;
create policy public_diagnostic_intakes_client_read on public.public_diagnostic_intakes for select to authenticated
using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER']));
revoke all on public.public_diagnostic_intakes from public,anon,authenticated,service_role;
grant select on public.public_diagnostic_intakes to authenticated;

create function public.save_public_diagnostic_intake(
  p_organization_id uuid,
  p_answers jsonb,
  p_locale text,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,private,extensions
as $$
declare
  actor uuid:=auth.uid();
  answer_key text;
  priorities jsonb:='[]'::jsonb;
  v_content_hash text;
  existing public.public_diagnostic_intakes%rowtype;
  intake_id uuid;
  response jsonb;
begin
  if actor is null or not private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER'],actor) then
    raise exception 'PUBLIC_DIAGNOSTIC_INTAKE_DENIED' using errcode='42501';
  end if;
  if p_locale not in('fr','ar') or p_idempotency_key!~'^[0-9a-f]{64}$' or jsonb_typeof(p_answers)<>'object'
     or (select count(*) from jsonb_object_keys(p_answers))<>8 or pg_column_size(p_answers)>8192 then
    raise exception 'INVALID_PUBLIC_DIAGNOSTIC_INTAKE' using errcode='22023';
  end if;
  for answer_key in select jsonb_object_keys(p_answers) loop
    if answer_key not in('goals','sector','team_size','priority_tracking','sales_tracking','backup_restore','decision_trace','next_action') then
      raise exception 'INVALID_PUBLIC_DIAGNOSTIC_INTAKE' using errcode='22023';
    end if;
  end loop;
  if jsonb_typeof(p_answers->'goals')<>'array' or jsonb_array_length(p_answers->'goals') not between 1 and 5
     or exists(select 1 from jsonb_array_elements_text(p_answers->'goals') value where value not in('save_time','control_costs','grow_sales','secure_activity','global_review'))
     or p_answers->>'sector' not in('professional_services','commerce','construction','industry_logistics','other')
     or p_answers->>'team_size' not in('solo','small','medium','large')
     or p_answers->>'priority_tracking' not in('regular','partial','no','unknown')
     or p_answers->>'sales_tracking' not in('shared','manual','ad_hoc','unknown')
     or p_answers->>'backup_restore' not in('recent','old','no','unknown','not_applicable')
     or p_answers->>'decision_trace' not in('systematic','partial','no','unknown')
     or length(btrim(coalesce(p_answers->>'next_action',''))) not between 3 and 500 then
    raise exception 'INVALID_PUBLIC_DIAGNOSTIC_INTAKE' using errcode='22023';
  end if;

  if p_answers->>'priority_tracking' in('partial','no') then priorities:=priorities||'[{"code":"organization","reason":"priority_tracking"}]'::jsonb; end if;
  if p_answers->>'sales_tracking' in('manual','ad_hoc') or ((p_answers->'goals')?'grow_sales' and p_answers->>'sales_tracking'<>'shared') then priorities:=priorities||'[{"code":"sales","reason":"sales_tracking"}]'::jsonb; end if;
  if p_answers->>'backup_restore'='no' or ((p_answers->'goals')?'secure_activity' and p_answers->>'backup_restore'='old') then priorities:=priorities||'[{"code":"security","reason":"backup_restore"}]'::jsonb; end if;
  if p_answers->>'priority_tracking'='unknown' or p_answers->>'sales_tracking'='unknown' or p_answers->>'backup_restore'='unknown' or p_answers->>'decision_trace'='unknown' then priorities:=priorities||'[{"code":"verify","reason":"declared_unknown"}]'::jsonb; end if;
  priorities:=(select coalesce(jsonb_agg(value order by ordinal),'[]'::jsonb) from (select value,ordinal from jsonb_array_elements(priorities) with ordinality ordered(value,ordinal) order by ordinal limit 3) bounded);
  v_content_hash:=encode(extensions.digest(convert_to(jsonb_build_object('projection_version','PUBLIC_INTAKE_V1','organization_id',p_organization_id,'answers',p_answers)::text,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended('public-diagnostic-intake:'||p_organization_id::text||':'||v_content_hash,0));
  select * into existing
  from public.public_diagnostic_intakes intake
  where intake.organization_id=p_organization_id and intake.content_hash=v_content_hash;
  if found then return jsonb_build_object('outcome','PUBLIC_DIAGNOSTIC_INTAKE_SAVED','intake_id',existing.id,'status',existing.status,'priorities',existing.priorities,'replayed',true); end if;

  insert into public.public_diagnostic_intakes(organization_id,created_by,locale,answers,priorities,content_hash)
    values(p_organization_id,actor,p_locale,p_answers,priorities,v_content_hash) returning id into intake_id;
  response:=jsonb_build_object('outcome','PUBLIC_DIAGNOSTIC_INTAKE_SAVED','intake_id',intake_id,'status','INDICATIVE','priorities',priorities,'replayed',false);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
    values(p_organization_id,actor,'USER','public_diagnostic.intake.saved','public_diagnostic_intake',intake_id::text,p_correlation_id,jsonb_build_object('projection_version','PUBLIC_INTAKE_V1','policy_version','PUBLIC_PRIORITY_V1','content_hash',v_content_hash),repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
    values(p_organization_id,'public_diagnostic_intake',intake_id::text,'PublicDiagnosticIntakeSavedV1',p_correlation_id,response,'public-diagnostic-intake:'||v_content_hash);
  return response;
end$$;
revoke all on function public.save_public_diagnostic_intake(uuid,jsonb,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.save_public_diagnostic_intake(uuid,jsonb,text,text,uuid) to authenticated;
