-- MARKETING-001..008 completeness: additive, tenant-scoped records omitted by the P18 foundation.
create table public.brand_assets(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  brand_kit_version_id uuid not null references public.brand_kit_versions(id) on delete restrict,
  asset_type text not null check(asset_type in('PRIMARY_LOGO','SECONDARY_LOGO','MONOCHROME_LOGO','PHOTO','VIDEO')),
  storage_path text not null check(storage_path!~'(^|/)(token|secret|password)(/|$)' and storage_path!~'\\.\\.'),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  usage_authorized boolean not null default false,
  valid_from timestamptz not null default clock_timestamp(),
  valid_until timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  check(valid_until is null or valid_until>valid_from),
  unique(brand_kit_version_id,asset_type,content_hash)
);

create table public.brand_claims(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  brand_kit_version_id uuid not null references public.brand_kit_versions(id) on delete restrict,
  claim_key text not null,
  text_fr text not null,
  text_ar text not null,
  evidence_reference text not null,
  status text not null check(status in('DRAFT','VERIFIED','REJECTED','EXPIRED')),
  valid_from timestamptz,
  valid_until timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  check(valid_until is null or valid_from is not null and valid_until>valid_from),
  unique(brand_kit_version_id,claim_key)
);

create table public.brand_restrictions(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  brand_kit_version_id uuid not null references public.brand_kit_versions(id) on delete restrict,
  restriction_type text not null check(restriction_type in('REQUIRED_MENTION','FORBIDDEN_TERM','FORBIDDEN_CLAIM','GEOGRAPHY','CHANNEL')),
  rule_payload jsonb not null check(jsonb_typeof(rule_payload)='object'),
  created_at timestamptz not null default clock_timestamp()
);

create table public.marketing_template_library_links(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_version_id uuid not null references public.marketing_template_versions(id) on delete restrict,
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  status text not null check(status in('PROPOSED','ACTIVE','REJECTED','RETIRED')),
  locked_sections text[] not null default '{}',
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,template_version_id,library_id)
);

create table public.social_accounts(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  connection_id uuid not null references public.social_connections(id) on delete restrict,
  provider_account_reference text not null check(length(btrim(provider_account_reference)) between 3 and 300),
  display_name text not null,
  status text not null check(status in('ACTIVE','DISCONNECTED','ERROR')),
  created_at timestamptz not null default clock_timestamp(),
  unique(connection_id,provider_account_reference)
);

create table public.marketing_schedule_rules(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  social_account_id uuid not null references public.social_accounts(id) on delete restrict,
  version integer not null check(version>0),
  status text not null check(status in('DRAFT','ACTIVE','RETIRED')),
  timezone text not null,
  posts_per_month integer not null default 8 check(posts_per_month between 0 and 100),
  reels_per_month integer not null default 4 check(reels_per_month between 0 and 100),
  generation_day integer not null default 25 check(generation_day between 1 and 28),
  allowed_slots jsonb not null check(jsonb_typeof(allowed_slots)='array'),
  max_service_repetition integer not null default 2 check(max_service_repetition between 1 and 20),
  privacy_minimum_aggregate integer not null default 10 check(privacy_minimum_aggregate between 3 and 1000),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,social_account_id,version)
);

create index marketing_schedule_rules_versions_idx on public.marketing_schedule_rules(organization_id,social_account_id,status,version desc);

create table public.marketing_schedule_rule_heads(
  organization_id uuid not null references public.organizations(id) on delete restrict,
  social_account_id uuid not null references public.social_accounts(id) on delete restrict,
  current_rule_id uuid not null references public.marketing_schedule_rules(id) on delete restrict,
  row_version integer not null default 1 check(row_version>0),
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default clock_timestamp(),
  primary key(organization_id,social_account_id),
  unique(current_rule_id)
);

create table public.marketing_calendars(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  schedule_rule_id uuid not null references public.marketing_schedule_rules(id) on delete restrict,
  month_start date not null check(month_start=date_trunc('month',month_start)::date),
  status text not null check(status in('DRAFT','GENERATED','VALIDATED_BY_RULES','APPROVED','SCHEDULED','PUBLISHED','FAILED','SKIPPED','CANCELLED')),
  generated_at timestamptz,
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  row_version integer not null default 1 check(row_version>0),
  created_at timestamptz not null default clock_timestamp(),
  check((approved_by is null)=(approved_at is null)),
  unique(organization_id,schedule_rule_id,month_start)
);

alter table public.marketing_calendar_items add column calendar_id uuid references public.marketing_calendars(id) on delete restrict;

-- Preserve already scheduled development data while making the V1 calendar relation mandatory.
insert into public.social_accounts(organization_id,connection_id,provider_account_reference,display_name,status)
select c.organization_id,c.id,'legacy:'||c.id::text,c.provider||' account',case when c.status='ACTIVE' then 'ACTIVE' else 'DISCONNECTED' end
from public.social_connections c
where exists(select 1 from public.marketing_calendar_items i where i.social_connection_id=c.id)
on conflict(connection_id,provider_account_reference) do nothing;

insert into public.marketing_schedule_rules(organization_id,social_account_id,version,status,timezone,allowed_slots,content_hash,created_by)
select a.organization_id,a.id,1,'ACTIVE','UTC','[]'::jsonb,encode(extensions.digest('legacy-schedule:'||a.id::text,'sha256'),'hex'),c.connected_by
from public.social_accounts a join public.social_connections c on c.id=a.connection_id
where exists(select 1 from public.marketing_calendar_items i where i.social_connection_id=c.id)
on conflict(organization_id,social_account_id,version) do nothing;

insert into public.marketing_schedule_rule_heads(organization_id,social_account_id,current_rule_id,updated_by)
select r.organization_id,r.social_account_id,r.id,r.created_by
from public.marketing_schedule_rules r
where r.status='ACTIVE' and not exists(select 1 from public.marketing_schedule_rules newer where newer.organization_id=r.organization_id and newer.social_account_id=r.social_account_id and newer.status='ACTIVE' and (newer.version,newer.id)>(r.version,r.id))
on conflict(organization_id,social_account_id) do nothing;

insert into public.marketing_calendars(organization_id,schedule_rule_id,month_start,status,generated_at)
select distinct c.organization_id,r.id,date_trunc('month',i.scheduled_at)::date,'SCHEDULED',clock_timestamp()
from public.marketing_calendar_items i
join public.marketing_campaigns c on c.id=i.campaign_id
join public.social_accounts a on a.connection_id=i.social_connection_id and a.organization_id=c.organization_id
join public.marketing_schedule_rule_heads h on h.social_account_id=a.id and h.organization_id=c.organization_id
join public.marketing_schedule_rules r on r.id=h.current_rule_id
on conflict(organization_id,schedule_rule_id,month_start) do nothing;

update public.marketing_calendar_items i set calendar_id=cal.id
from public.marketing_campaigns c,public.social_accounts a,public.marketing_schedule_rule_heads h,public.marketing_schedule_rules r,public.marketing_calendars cal
where c.id=i.campaign_id and a.connection_id=i.social_connection_id and a.organization_id=c.organization_id
and h.social_account_id=a.id and h.organization_id=c.organization_id and r.id=h.current_rule_id
and cal.schedule_rule_id=r.id and cal.organization_id=c.organization_id and cal.month_start=date_trunc('month',i.scheduled_at)::date;

alter table public.marketing_calendar_items alter column calendar_id set not null;
create index marketing_calendar_items_calendar_idx on public.marketing_calendar_items(calendar_id,scheduled_at);

create function private.marketing_snapshot_keys_allowed(p_snapshot jsonb,p_allowed text[]) returns boolean
language sql immutable strict set search_path=pg_catalog as $$
  select jsonb_typeof(p_snapshot)='object'
    and not exists(select 1 from jsonb_object_keys(p_snapshot) key where not(key=any(p_allowed)))
$$;

create table public.marketing_trend_snapshots(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  library_id uuid references public.catalog_libraries(id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  segment jsonb not null check(jsonb_typeof(segment)='object'),
  privacy_policy_version text not null check(length(btrim(privacy_policy_version)) between 1 and 100),
  minimum_aggregate_size integer not null check(minimum_aggregate_size between 3 and 1000),
  aggregate_size integer not null,
  anomaly_count bigint not null check(anomaly_count>=0),
  growth_basis_points integer,
  source_hash text not null check(source_hash~'^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  check(period_end>=period_start),
  check(aggregate_size>=minimum_aggregate_size),
  check(private.marketing_snapshot_keys_allowed(segment,array['sector','size_band','region'])),
  unique(organization_id,library_id,service_id,period_start,period_end,source_hash)
);

create table public.campaign_suggestions(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  trend_snapshot_id uuid not null references public.marketing_trend_snapshots(id) on delete restrict,
  title_fr text not null,
  title_ar text not null,
  rationale_fr text not null,
  rationale_ar text not null,
  status text not null check(status in('PROPOSED','ACCEPTED','REJECTED','EXPIRED')),
  risk_score integer not null check(risk_score between 0 and 100),
  created_at timestamptz not null default clock_timestamp(),
  unique(organization_id,trend_snapshot_id)
);

create table public.marketing_campaign_targets(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  campaign_id uuid not null references public.marketing_campaigns(id) on delete restrict,
  library_id uuid references public.catalog_libraries(id) on delete restrict,
  service_id uuid references public.catalog_services(id) on delete restrict,
  audience_snapshot jsonb not null check(jsonb_typeof(audience_snapshot)='object'),
  privacy_policy_version text not null check(length(btrim(privacy_policy_version)) between 1 and 100),
  minimum_aggregate_size integer not null check(minimum_aggregate_size between 3 and 1000),
  aggregate_size integer not null,
  created_at timestamptz not null default clock_timestamp(),
  check(aggregate_size>=minimum_aggregate_size),
  check(private.marketing_snapshot_keys_allowed(audience_snapshot,array['sector','size_band','region','channel','language'])),
  unique(campaign_id,library_id,service_id)
);

create table public.marketing_leads(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  campaign_id uuid not null references public.marketing_campaigns(id) on delete restrict,
  visitor_hash text not null check(visitor_hash~'^[0-9a-f]{64}$'),
  first_touch_at timestamptz not null,
  last_touch_at timestamptz not null,
  status text not null check(status in('ANONYMOUS','REGISTERED','QUALIFIED','CONVERTED','SUPPRESSED')),
  created_at timestamptz not null default clock_timestamp(),
  check(last_touch_at>=first_touch_at),
  unique(organization_id,campaign_id,visitor_hash)
);

create table public.marketing_conversion_paths(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  lead_id uuid not null references public.marketing_leads(id) on delete restrict,
  attribution_model text not null default 'LAST_NON_DIRECT_CLICK' check(attribution_model in('LAST_NON_DIRECT_CLICK','FIRST_CLICK','LINEAR')),
  touchpoints jsonb not null check(jsonb_typeof(touchpoints)='array'),
  attributed_campaign_id uuid references public.marketing_campaigns(id) on delete restrict,
  attributed_value_minor bigint check(attributed_value_minor is null or attributed_value_minor>=0),
  currency char(3) check(currency is null or currency~'^[A-Z]{3}$'),
  computed_at timestamptz not null default clock_timestamp(),
  check((attributed_value_minor is null)=(currency is null)),
  unique(lead_id,computed_at)
);

create function private.prevent_marketing_v1_history_change() returns trigger language plpgsql set search_path=pg_catalog as $$begin raise exception 'MARKETING_HISTORY_IMMUTABLE' using errcode='55000'; end$$;

create function private.enforce_marketing_v1_tenant_scope() returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare expected_org uuid;
begin
  case tg_table_name
    when 'brand_assets','brand_claims','brand_restrictions' then select k.organization_id into expected_org from public.brand_kit_versions v join public.brand_kits k on k.id=v.brand_kit_id where v.id=new.brand_kit_version_id;
    when 'social_accounts' then select organization_id into expected_org from public.social_connections where id=new.connection_id;
    when 'marketing_schedule_rules' then select organization_id into expected_org from public.social_accounts where id=new.social_account_id;
    when 'marketing_schedule_rule_heads' then
      select a.organization_id into expected_org from public.social_accounts a join public.marketing_schedule_rules r on r.id=new.current_rule_id and r.social_account_id=a.id and r.organization_id=a.organization_id and r.status='ACTIVE' where a.id=new.social_account_id;
    when 'marketing_calendars' then select organization_id into expected_org from public.marketing_schedule_rules where id=new.schedule_rule_id;
    when 'campaign_suggestions' then select organization_id into expected_org from public.marketing_trend_snapshots where id=new.trend_snapshot_id;
    when 'marketing_campaign_targets','marketing_leads' then select organization_id into expected_org from public.marketing_campaigns where id=new.campaign_id;
    when 'marketing_conversion_paths' then
      select organization_id into expected_org from public.marketing_leads where id=new.lead_id;
      if new.attributed_campaign_id is not null and not exists(select 1 from public.marketing_campaigns c where c.id=new.attributed_campaign_id and c.organization_id=expected_org) then raise exception 'MARKETING_CROSS_TENANT_REFERENCE' using errcode='42501'; end if;
    when 'marketing_calendar_items' then
      if new.calendar_id is null then return new; end if;
      select c.organization_id into expected_org from public.marketing_calendars c join public.marketing_schedule_rules r on r.id=c.schedule_rule_id join public.social_accounts a on a.id=r.social_account_id where c.id=new.calendar_id and a.connection_id=new.social_connection_id and c.month_start=date_trunc('month',new.scheduled_at)::date;
      if expected_org is null or not exists(select 1 from public.marketing_campaigns m where m.id=new.campaign_id and m.organization_id=expected_org) then raise exception 'MARKETING_CALENDAR_SCOPE_MISMATCH' using errcode='42501'; end if;
      return new;
    when 'marketing_template_library_links' then expected_org:=new.organization_id;
    else raise exception 'UNSUPPORTED_MARKETING_TENANT_TABLE' using errcode='55000';
  end case;
  if expected_org is null or expected_org<>new.organization_id then raise exception 'MARKETING_CROSS_TENANT_REFERENCE' using errcode='42501'; end if;
  return new;
end$$;

create trigger brand_assets_tenant before insert or update on public.brand_assets for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger brand_claims_tenant before insert or update on public.brand_claims for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger brand_restrictions_tenant before insert or update on public.brand_restrictions for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger social_accounts_tenant before insert or update on public.social_accounts for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_schedule_rules_tenant before insert or update on public.marketing_schedule_rules for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_schedule_rule_heads_tenant before insert or update on public.marketing_schedule_rule_heads for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_calendars_tenant before insert or update on public.marketing_calendars for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger campaign_suggestions_tenant before insert or update on public.campaign_suggestions for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_campaign_targets_tenant before insert or update on public.marketing_campaign_targets for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_leads_tenant before insert or update on public.marketing_leads for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_conversion_paths_tenant before insert or update on public.marketing_conversion_paths for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_template_library_links_tenant before insert or update on public.marketing_template_library_links for each row execute function private.enforce_marketing_v1_tenant_scope();
create trigger marketing_calendar_items_calendar_tenant before insert or update on public.marketing_calendar_items for each row execute function private.enforce_marketing_v1_tenant_scope();

do $$declare t text;begin
  foreach t in array array['brand_assets','brand_claims','brand_restrictions','marketing_template_library_links','social_accounts','marketing_schedule_rules','marketing_schedule_rule_heads','marketing_calendars','marketing_trend_snapshots','campaign_suggestions','marketing_campaign_targets','marketing_leads','marketing_conversion_paths'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
    execute format('create policy %I on public.%I for select to authenticated using (private.marketing_manage_access(organization_id) or private.has_platform_role(array[''READ_ONLY_AUDITOR'']))',t||'_scoped_read',t);
  end loop;
end$$;

grant select on public.brand_assets,public.brand_claims,public.brand_restrictions,public.marketing_template_library_links,public.social_accounts,public.marketing_schedule_rules,public.marketing_schedule_rule_heads,public.marketing_calendars,public.marketing_trend_snapshots,public.campaign_suggestions,public.marketing_campaign_targets,public.marketing_leads,public.marketing_conversion_paths to authenticated;

create trigger marketing_schedule_rules_immutable before update or delete on public.marketing_schedule_rules for each row execute function private.prevent_marketing_v1_history_change();
create trigger marketing_trends_immutable before update or delete on public.marketing_trend_snapshots for each row execute function private.prevent_marketing_v1_history_change();
create trigger marketing_conversion_paths_immutable before update or delete on public.marketing_conversion_paths for each row execute function private.prevent_marketing_v1_history_change();

create index brand_assets_org_version_idx on public.brand_assets(organization_id,brand_kit_version_id);
create index brand_claims_org_status_idx on public.brand_claims(organization_id,status,valid_until);
create index marketing_template_library_links_idx on public.marketing_template_library_links(organization_id,library_id,status);
create index marketing_calendars_org_month_idx on public.marketing_calendars(organization_id,month_start,status);
create index marketing_trends_period_idx on public.marketing_trend_snapshots(organization_id,period_end desc);
create index campaign_suggestions_queue_idx on public.campaign_suggestions(organization_id,status,created_at desc);
create index marketing_leads_campaign_idx on public.marketing_leads(organization_id,campaign_id,last_touch_at desc);
create index marketing_paths_lead_idx on public.marketing_conversion_paths(organization_id,lead_id,computed_at desc);

revoke all on function private.prevent_marketing_v1_history_change() from public,anon,authenticated,service_role;
revoke all on function private.enforce_marketing_v1_tenant_scope() from public,anon,authenticated,service_role;
revoke all on function private.marketing_snapshot_keys_allowed(jsonb,text[]) from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
