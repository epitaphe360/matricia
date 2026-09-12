-- V1 MAT-FUNC-034/035/047/062: governed rewards, traceable referrals and evidence-backed ROI/savings.

create table public.reward_rule_versions(
 id uuid primary key default extensions.gen_random_uuid(),
 rule_code text not null check(rule_code~'^[A-Z][A-Z0-9_]{2,63}$'),
 version_number integer not null check(version_number>0),
 status text not null check(status in('DRAFT','ACTIVE','PAUSED','RETIRED')),
 trigger_event text not null check(trigger_event~'^[A-Z][A-Z0-9_.]{2,79}$'),
 audience_type text not null check(audience_type in('CLIENT_ORGANIZATION','REFERRED_CLIENT','REFERRED_PROVIDER')),
 bonus_credits bigint not null check(bonus_credits>0),
 per_recipient_cap_credits bigint not null check(per_recipient_cap_credits>=bonus_credits),
 global_cap_credits bigint not null check(global_cap_credits>=per_recipient_cap_credits),
 window_days integer not null check(window_days between 1 and 366),
 cooldown_hours integer not null check(cooldown_hours between 0 and 8760),
 credit_validity_days integer not null check(credit_validity_days between 1 and 3660),
 eligibility_rule jsonb not null check(jsonb_typeof(eligibility_rule)='object'),
 requires_approval boolean not null default true,
 effective_from timestamptz not null,
 effective_until timestamptz,
 content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
 change_reason text not null check(length(btrim(change_reason)) between 3 and 1000),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 unique(rule_code,version_number),unique(id,rule_code),
 check(effective_until is null or effective_until>effective_from)
);
create index reward_rule_active_idx on public.reward_rule_versions(rule_code,effective_from,effective_until) where status='ACTIVE';
create index reward_rule_effective_idx on public.reward_rule_versions(status,effective_from,effective_until);

create table public.reward_grants(
 id uuid primary key default extensions.gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 wallet_id uuid not null,
 rule_version_id uuid not null references public.reward_rule_versions(id) on delete restrict,
 rule_code text not null,
 trigger_reference_type text not null check(trigger_reference_type~'^[A-Z][A-Z0-9_]{2,63}$'),
 trigger_reference_id text not null check(length(btrim(trigger_reference_id)) between 3 and 200),
 anti_abuse_key_hash text not null check(anti_abuse_key_hash~'^[0-9a-f]{64}$'),
 eligibility_evidence jsonb not null check(jsonb_typeof(eligibility_evidence)='object'),
 quantity bigint not null check(quantity>0),
 credit_ledger_entry_id bigint not null references public.credit_ledger_entries(id) on delete restrict,
 credit_lot_id uuid not null references public.credit_lots(id) on delete restrict,
 approval_reference text not null check(length(btrim(approval_reference)) between 3 and 200),
 correlation_id uuid not null,
 idempotency_key text not null check(length(idempotency_key) between 8 and 200),
 granted_by uuid not null references auth.users(id),
 granted_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,wallet_id) references public.credit_wallets(organization_id,id) on delete restrict,
 foreign key(rule_version_id,rule_code) references public.reward_rule_versions(id,rule_code) on delete restrict,
 unique(rule_code,trigger_reference_type,trigger_reference_id),
 unique(rule_code,anti_abuse_key_hash),
 unique(organization_id,idempotency_key)
);
create index reward_grants_recipient_window_idx on public.reward_grants(organization_id,rule_code,granted_at desc);
create index reward_grants_rule_window_idx on public.reward_grants(rule_code,granted_at desc);

create table public.referral_links(
 id uuid primary key default extensions.gen_random_uuid(),
 source_organization_id uuid not null references public.organizations(id) on delete restrict,
 referral_code text not null check(referral_code~'^[A-Z0-9][A-Z0-9_-]{7,63}$'),
 audience_type text not null check(audience_type in('CLIENT','PROVIDER')),
 campaign_reference text not null check(length(btrim(campaign_reference)) between 3 and 120),
 status text not null check(status in('ACTIVE','PAUSED','EXPIRED','REVOKED')),
 expires_at timestamptz not null,
 max_conversions integer not null check(max_conversions between 1 and 100000),
 created_by uuid not null references auth.users(id),
 correlation_id uuid not null,
 created_at timestamptz not null default clock_timestamp(),
 unique(referral_code),unique(id,source_organization_id),
 check(expires_at>created_at)
);
create index referral_links_source_idx on public.referral_links(source_organization_id,status,expires_at desc);

create table public.referral_touchpoints(
 id bigint generated always as identity primary key,
 referral_link_id uuid not null references public.referral_links(id) on delete restrict,
 source_organization_id uuid not null,
 touchpoint_type text not null check(touchpoint_type in('LINK_OPENED','REGISTRATION_STARTED')),
 visitor_key_hash text not null check(visitor_key_hash~'^[0-9a-f]{64}$'),
 occurred_at timestamptz not null default clock_timestamp(),
 correlation_id uuid not null,
 actor_user_id uuid references auth.users(id),
 foreign key(referral_link_id,source_organization_id) references public.referral_links(id,source_organization_id) on delete restrict,
 unique(referral_link_id,touchpoint_type,visitor_key_hash)
);
create index referral_touchpoints_link_idx on public.referral_touchpoints(referral_link_id,occurred_at desc);

create table public.referral_conversions(
 id uuid primary key default extensions.gen_random_uuid(),
 referral_link_id uuid not null references public.referral_links(id) on delete restrict,
 source_organization_id uuid not null,
 target_organization_id uuid not null references public.organizations(id) on delete restrict,
 conversion_stage text not null check(conversion_stage in('REGISTERED','PROFILE_STARTED','VERIFIED','ACTIVE')),
 origin_snapshot jsonb not null check(jsonb_typeof(origin_snapshot)='object'),
 registered_by uuid not null references auth.users(id),
 registered_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 row_version integer not null default 1 check(row_version>0),
 foreign key(referral_link_id,source_organization_id) references public.referral_links(id,source_organization_id) on delete restrict,
 unique(target_organization_id),unique(id,source_organization_id),
 check(source_organization_id<>target_organization_id)
);
create index referral_conversions_source_idx on public.referral_conversions(source_organization_id,conversion_stage,registered_at desc);
create index referral_conversions_target_idx on public.referral_conversions(target_organization_id,registered_at desc);

create table public.referral_conversion_events(
 id bigint generated always as identity primary key,
 referral_conversion_id uuid not null references public.referral_conversions(id) on delete restrict,
 source_organization_id uuid not null,
 from_stage text,
 to_stage text not null check(to_stage in('REGISTERED','PROFILE_STARTED','VERIFIED','ACTIVE')),
 evidence_refs jsonb not null check(jsonb_typeof(evidence_refs)='array' and jsonb_array_length(evidence_refs)>0),
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),
 correlation_id uuid not null,
 actor_user_id uuid not null references auth.users(id),
 occurred_at timestamptz not null default clock_timestamp(),
 foreign key(referral_conversion_id,source_organization_id) references public.referral_conversions(id,source_organization_id) on delete restrict,
 unique(referral_conversion_id,to_stage)
);
create index referral_conversion_events_idx on public.referral_conversion_events(referral_conversion_id,id);

create table public.measurement_baselines(
 id uuid primary key default extensions.gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 subject_type text not null check(subject_type in('RECOMMENDATION','OPPORTUNITY','SERVICE','PROJECT','CONTRACT','ORGANIZATION')),
 subject_id uuid not null,
 metric_code text not null check(metric_code~'^[A-Z][A-Z0-9_]{2,63}$'),
 version_number integer not null check(version_number>0),
 baseline_amount_minor bigint not null check(baseline_amount_minor>=0),
 currency char(3) not null check(currency~'^[A-Z]{3}$'),
 period_start date not null,
 period_end date not null,
 source_type text not null check(source_type in('INVOICE','CONTRACT','ACCOUNTING_EXPORT','METER_READING','SIGNED_REPORT','AUDITED_IMPORT')),
 source_reference text not null check(length(btrim(source_reference)) between 3 and 240),
 evidence_refs jsonb not null check(jsonb_typeof(evidence_refs)='array' and jsonb_array_length(evidence_refs)>0),
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),
 methodology_version text not null check(methodology_version~'^[A-Z0-9][A-Z0-9._-]{2,79}$'),
 verification_status text not null check(verification_status='VERIFIED'),
 verified_by uuid not null references auth.users(id),
 verified_at timestamptz not null default clock_timestamp(),
 correlation_id uuid not null,
 created_at timestamptz not null default clock_timestamp(),
 unique(organization_id,subject_type,subject_id,metric_code,version_number),unique(id,organization_id),
 check(period_end>=period_start)
);
create index measurement_baselines_subject_idx on public.measurement_baselines(organization_id,subject_type,subject_id,metric_code,version_number desc);

create table public.recommendation_roi_snapshots(
 id uuid primary key default extensions.gen_random_uuid(),
 organization_id uuid not null,
 recommendation_id uuid not null,
 baseline_id uuid not null,
 actual_amount_minor bigint not null check(actual_amount_minor>=0),
 realized_value_minor bigint not null,
 implementation_cost_minor bigint not null check(implementation_cost_minor>0),
 net_value_minor bigint not null,
 roi_basis_points bigint not null,
 currency char(3) not null check(currency~'^[A-Z]{3}$'),
 actual_period_start date not null,
 actual_period_end date not null,
 actual_source_type text not null check(actual_source_type in('INVOICE','CONTRACT','ACCOUNTING_EXPORT','METER_READING','SIGNED_REPORT','AUDITED_IMPORT')),
 actual_source_reference text not null check(length(btrim(actual_source_reference)) between 3 and 240),
 evidence_refs jsonb not null check(jsonb_typeof(evidence_refs)='array' and jsonb_array_length(evidence_refs)>0),
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),
 formula_version text not null check(formula_version~'^[A-Z0-9][A-Z0-9._-]{2,79}$'),
 explanation jsonb not null check(jsonb_typeof(explanation)='object'),
 calculated_by uuid not null references auth.users(id),
 correlation_id uuid not null,
 calculated_at timestamptz not null default clock_timestamp(),
 foreign key(recommendation_id,organization_id) references public.diagnostic_recommendations(id,organization_id) on delete restrict,
 foreign key(baseline_id,organization_id) references public.measurement_baselines(id,organization_id) on delete restrict,
 unique(recommendation_id,baseline_id,actual_period_start,actual_period_end)
);
create index recommendation_roi_org_idx on public.recommendation_roi_snapshots(organization_id,calculated_at desc);

create table public.savings_measurements(
 id uuid primary key default extensions.gen_random_uuid(),
 organization_id uuid not null,
 baseline_id uuid not null,
 actual_amount_minor bigint not null check(actual_amount_minor>=0),
 savings_amount_minor bigint not null check(savings_amount_minor>=0),
 currency char(3) not null check(currency~'^[A-Z]{3}$'),
 actual_period_start date not null,
 actual_period_end date not null,
 source_type text not null check(source_type in('INVOICE','CONTRACT','ACCOUNTING_EXPORT','METER_READING','SIGNED_REPORT','AUDITED_IMPORT')),
 source_reference text not null check(length(btrim(source_reference)) between 3 and 240),
 evidence_refs jsonb not null check(jsonb_typeof(evidence_refs)='array' and jsonb_array_length(evidence_refs)>0),
 evidence_hash text not null check(evidence_hash~'^[0-9a-f]{64}$'),
 formula_version text not null check(formula_version~'^[A-Z0-9][A-Z0-9._-]{2,79}$'),
 explanation jsonb not null check(jsonb_typeof(explanation)='object'),
 recorded_by uuid not null references auth.users(id),
 correlation_id uuid not null,
 recorded_at timestamptz not null default clock_timestamp(),
 foreign key(baseline_id,organization_id) references public.measurement_baselines(id,organization_id) on delete restrict,
 unique(baseline_id,actual_period_start,actual_period_end),
 check(actual_period_end>=actual_period_start)
);
create index savings_measurements_org_idx on public.savings_measurements(organization_id,recorded_at desc);

do $$declare t text;begin foreach t in array array['reward_rule_versions','reward_grants','referral_links','referral_touchpoints','referral_conversions','referral_conversion_events','measurement_baselines','recommendation_roi_snapshots','savings_measurements'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);end loop;end$$;

create trigger reward_rule_versions_immutable before update or delete on public.reward_rule_versions for each row execute function private.prevent_update_delete();
create trigger reward_grants_immutable before update or delete on public.reward_grants for each row execute function private.prevent_update_delete();
create trigger referral_touchpoints_immutable before update or delete on public.referral_touchpoints for each row execute function private.prevent_update_delete();
create trigger referral_conversion_events_immutable before update or delete on public.referral_conversion_events for each row execute function private.prevent_update_delete();
create trigger measurement_baselines_immutable before update or delete on public.measurement_baselines for each row execute function private.prevent_update_delete();
create trigger recommendation_roi_snapshots_immutable before update or delete on public.recommendation_roi_snapshots for each row execute function private.prevent_update_delete();
create trigger savings_measurements_immutable before update or delete on public.savings_measurements for each row execute function private.prevent_update_delete();

create function private.begin_rewards_command(p_organization_id uuid,p_actor uuid,p_scope text,p_key text,p_hash text) returns jsonb language plpgsql security definer set search_path=pg_catalog,public as $$declare v public.idempotency_keys%rowtype;begin
 if p_actor is null then raise exception'AUTHENTICATION_REQUIRED'using errcode='42501';end if;if length(coalesce(p_key,''))not between 8 and 200 or p_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_COMMAND_IDENTITY'using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text||':'||p_scope||':'||p_key,0));select*into v from public.idempotency_keys where organization_id=p_organization_id and operation_scope=p_scope and key=p_key for update;
 if found then if v.request_hash<>p_hash then raise exception'IDEMPOTENCY_PAYLOAD_MISMATCH'using errcode='22000';end if;if v.status='COMPLETED'then return v.response_body;end if;raise exception'IDEMPOTENCY_IN_PROGRESS'using errcode='55000';end if;
 insert into public.idempotency_keys(organization_id,operation_scope,key,request_hash,created_by,expires_at)values(p_organization_id,p_scope,p_key,p_hash,p_actor,clock_timestamp()+interval'30 days');return null;end$$;
create function private.finish_rewards_command(p_organization_id uuid,p_scope text,p_key text,p_response jsonb) returns void language sql security definer set search_path=pg_catalog,public as $$update public.idempotency_keys set status='COMPLETED',response_code=200,response_body=p_response,completed_at=clock_timestamp()where organization_id=p_organization_id and operation_scope=p_scope and key=p_key$$;
revoke all on function private.begin_rewards_command(uuid,uuid,text,text,text),private.finish_rewards_command(uuid,text,text,jsonb) from public,anon,authenticated,service_role;

create function public.create_reward_rule_version(p_rule_code text,p_status text,p_trigger_event text,p_audience_type text,p_bonus_credits bigint,p_per_recipient_cap_credits bigint,p_global_cap_credits bigint,p_window_days integer,p_cooldown_hours integer,p_credit_validity_days integer,p_eligibility_rule jsonb,p_requires_approval boolean,p_effective_from timestamptz,p_effective_until timestamptz,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();command_org uuid;n integer;h text;cached jsonb;x uuid;r jsonb;ch text;begin
 if not private.credits_admin_access(a)then raise exception'REWARD_RULE_ADMIN_REQUIRED'using errcode='42501';end if;if p_status not in('DRAFT','ACTIVE','PAUSED','RETIRED')or p_rule_code!~'^[A-Z][A-Z0-9_]{2,63}$'or p_trigger_event!~'^[A-Z][A-Z0-9_.]{2,79}$'or p_audience_type not in('CLIENT_ORGANIZATION','REFERRED_CLIENT','REFERRED_PROVIDER')or p_bonus_credits<=0 or p_per_recipient_cap_credits<p_bonus_credits or p_global_cap_credits<p_per_recipient_cap_credits or p_window_days not between 1 and 366 or p_cooldown_hours not between 0 and 8760 or p_credit_validity_days not between 1 and 3660 or jsonb_typeof(p_eligibility_rule)<>'object'or p_effective_until is not null and p_effective_until<=p_effective_from or length(btrim(coalesce(p_change_reason,'')))not between 3 and 1000 then raise exception'INVALID_REWARD_RULE'using errcode='22023';end if;
 select m.organization_id into command_org from public.organization_memberships m where m.user_id=a and m.status='ACTIVE' order by m.organization_id limit 1;if command_org is null then raise exception'COMMAND_ORGANIZATION_REQUIRED'using errcode='42501';end if;h:=private.canonical_request_hash(jsonb_build_object('code',p_rule_code,'status',p_status,'trigger',p_trigger_event,'audience',p_audience_type,'bonus',p_bonus_credits,'recipient_cap',p_per_recipient_cap_credits,'global_cap',p_global_cap_credits,'window_days',p_window_days,'cooldown_hours',p_cooldown_hours,'validity_days',p_credit_validity_days,'eligibility',p_eligibility_rule,'approval',p_requires_approval,'from',p_effective_from,'until',p_effective_until,'reason',p_change_reason));cached:=private.begin_rewards_command(command_org,a,'reward.rule.create',p_idempotency_key,h);if cached is not null then return cached;end if;
 perform pg_advisory_xact_lock(hashtextextended('reward-rule:'||p_rule_code,0));if p_status='ACTIVE'and exists(select 1 from public.reward_rule_versions q where q.rule_code=p_rule_code and q.status='ACTIVE'and tstzrange(q.effective_from,q.effective_until,'[)')&&tstzrange(p_effective_from,p_effective_until,'[)'))then raise exception'REWARD_RULE_EFFECTIVE_WINDOW_OVERLAP'using errcode='23514';end if;select coalesce(max(version_number),0)+1 into n from public.reward_rule_versions where rule_code=p_rule_code;ch:=encode(extensions.digest(convert_to(h,'UTF8'),'sha256'),'hex');insert into public.reward_rule_versions(rule_code,version_number,status,trigger_event,audience_type,bonus_credits,per_recipient_cap_credits,global_cap_credits,window_days,cooldown_hours,credit_validity_days,eligibility_rule,requires_approval,effective_from,effective_until,content_hash,change_reason,created_by)values(p_rule_code,n,p_status,p_trigger_event,p_audience_type,p_bonus_credits,p_per_recipient_cap_credits,p_global_cap_credits,p_window_days,p_cooldown_hours,p_credit_validity_days,p_eligibility_rule,p_requires_approval,p_effective_from,p_effective_until,ch,p_change_reason,a)returning id into x;
 r:=jsonb_build_object('outcome','REWARD_RULE_VERSION_CREATED','rule_version_id',x,'rule_code',p_rule_code,'version_number',n,'status',p_status);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(command_org,a,'USER','reward.rule_version.created','reward_rule_version',x::text,p_correlation_id,r,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(command_org,'reward_rule',p_rule_code,'RewardRuleVersionCreatedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(command_org,'reward.rule.create',p_idempotency_key,r);return r;end$$;

create function public.award_reward(p_organization_id uuid,p_wallet_id uuid,p_rule_version_id uuid,p_trigger_reference_type text,p_trigger_reference_id text,p_anti_abuse_key_hash text,p_eligibility_evidence jsonb,p_approval_reference text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();v public.reward_rule_versions%rowtype;recipient_total bigint;global_total bigint;last_at timestamptz;h text;cached jsonb;grant_id uuid;issued jsonb;r jsonb;child_key text;begin
 if not private.credits_admin_access(a)then raise exception'REWARD_AWARD_ADMIN_REQUIRED'using errcode='42501';end if;select*into v from public.reward_rule_versions where id=p_rule_version_id and status='ACTIVE'and effective_from<=clock_timestamp()and(effective_until is null or effective_until>clock_timestamp());if not found then raise exception'ACTIVE_REWARD_RULE_REQUIRED'using errcode='22023';end if;
 if p_trigger_reference_type!~'^[A-Z][A-Z0-9_]{2,63}$'or length(btrim(coalesce(p_trigger_reference_id,'')))not between 3 and 200 or p_anti_abuse_key_hash!~'^[0-9a-f]{64}$'or jsonb_typeof(p_eligibility_evidence)<>'object'or not(p_eligibility_evidence@>v.eligibility_rule)or(v.requires_approval and length(btrim(coalesce(p_approval_reference,'')))not between 3 and 200)then raise exception'INVALID_REWARD_EVIDENCE'using errcode='22023';end if;perform 1 from public.credit_wallets where id=p_wallet_id and organization_id=p_organization_id and wallet_type='CLIENT'for update;if not found then raise exception'CLIENT_WALLET_NOT_FOUND'using errcode='P0002';end if;
 h:=private.canonical_request_hash(jsonb_build_object('organization',p_organization_id,'wallet',p_wallet_id,'rule_version',v.id,'trigger_type',p_trigger_reference_type,'trigger_id',p_trigger_reference_id,'anti_abuse_hash',p_anti_abuse_key_hash,'eligibility_evidence',p_eligibility_evidence,'approval',p_approval_reference));cached:=private.begin_rewards_command(p_organization_id,a,'reward.award',p_idempotency_key,h);if cached is not null then return cached;end if;perform pg_advisory_xact_lock(hashtextextended('reward-award:'||v.rule_code,0));
 select coalesce(sum(g.quantity),0),max(g.granted_at) into recipient_total,last_at from public.reward_grants g where g.organization_id=p_organization_id and g.rule_code=v.rule_code and g.granted_at>=clock_timestamp()-make_interval(days=>v.window_days);select coalesce(sum(g.quantity),0)into global_total from public.reward_grants g where g.rule_code=v.rule_code and g.granted_at>=clock_timestamp()-make_interval(days=>v.window_days);
 if recipient_total+v.bonus_credits>v.per_recipient_cap_credits then raise exception'REWARD_RECIPIENT_CAP_EXCEEDED'using errcode='23514';end if;if global_total+v.bonus_credits>v.global_cap_credits then raise exception'REWARD_GLOBAL_CAP_EXCEEDED'using errcode='23514';end if;if last_at is not null and last_at+make_interval(hours=>v.cooldown_hours)>clock_timestamp()then raise exception'REWARD_COOLDOWN_ACTIVE'using errcode='23514';end if;
 child_key:='reward-credit-'||encode(extensions.digest(convert_to(p_idempotency_key,'UTF8'),'sha256'),'hex');issued:=public.issue_credits(p_organization_id,p_wallet_id,'BONUS',v.bonus_credits,clock_timestamp()+make_interval(days=>v.credit_validity_days),null,'REWARD:'||v.rule_code||':'||p_trigger_reference_id,0,v.rule_code||'-V'||v.version_number::text,coalesce(p_approval_reference,'RULE_AUTO_APPROVED'),child_key,p_correlation_id);
 insert into public.reward_grants(organization_id,wallet_id,rule_version_id,rule_code,trigger_reference_type,trigger_reference_id,anti_abuse_key_hash,eligibility_evidence,quantity,credit_ledger_entry_id,credit_lot_id,approval_reference,correlation_id,idempotency_key,granted_by)values(p_organization_id,p_wallet_id,v.id,v.rule_code,p_trigger_reference_type,p_trigger_reference_id,p_anti_abuse_key_hash,p_eligibility_evidence,v.bonus_credits,(issued->>'entry_id')::bigint,(issued->>'credit_lot_id')::uuid,coalesce(p_approval_reference,'RULE_AUTO_APPROVED'),p_correlation_id,p_idempotency_key,a)returning id into grant_id;
 r:=jsonb_build_object('outcome','REWARD_GRANTED','reward_grant_id',grant_id,'rule_code',v.rule_code,'quantity',v.bonus_credits,'credit_lot_id',issued->'credit_lot_id');insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','reward.granted','reward_grant',grant_id::text,p_correlation_id,jsonb_build_object('rule_version_id',v.id,'trigger_reference_type',p_trigger_reference_type,'trigger_reference_id',p_trigger_reference_id,'quantity',v.bonus_credits),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'reward_grant',grant_id::text,'RewardGrantedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(p_organization_id,'reward.award',p_idempotency_key,r);return r;end$$;

create function public.create_referral_link(p_source_organization_id uuid,p_referral_code text,p_audience_type text,p_campaign_reference text,p_expires_at timestamptz,p_max_conversions integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();h text;cached jsonb;x uuid;r jsonb;begin
 if not(private.has_org_role(p_source_organization_id,array['FRANCHISE_OWNER','FRANCHISE_MANAGER','CLIENT_OWNER','CLIENT_ADMIN'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a))then raise exception'REFERRAL_LINK_CREATE_DENIED'using errcode='42501';end if;if upper(p_referral_code)!~'^[A-Z0-9][A-Z0-9_-]{7,63}$'or p_audience_type not in('CLIENT','PROVIDER')or length(btrim(coalesce(p_campaign_reference,'')))not between 3 and 120 or p_expires_at<=clock_timestamp()or p_expires_at>clock_timestamp()+interval'366 days'or p_max_conversions not between 1 and 100000 then raise exception'INVALID_REFERRAL_LINK'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('source',p_source_organization_id,'code',upper(p_referral_code),'audience',p_audience_type,'campaign',p_campaign_reference,'expires',p_expires_at,'max',p_max_conversions));cached:=private.begin_rewards_command(p_source_organization_id,a,'referral.link.create',p_idempotency_key,h);if cached is not null then return cached;end if;insert into public.referral_links(source_organization_id,referral_code,audience_type,campaign_reference,status,expires_at,max_conversions,created_by,correlation_id)values(p_source_organization_id,upper(p_referral_code),p_audience_type,p_campaign_reference,'ACTIVE',p_expires_at,p_max_conversions,a,p_correlation_id)returning id into x;
 r:=jsonb_build_object('outcome','REFERRAL_LINK_CREATED','referral_link_id',x,'referral_code',upper(p_referral_code),'expires_at',p_expires_at);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_source_organization_id,a,'USER','referral.link.created','referral_link',x::text,p_correlation_id,jsonb_build_object('audience_type',p_audience_type,'campaign_reference',p_campaign_reference,'max_conversions',p_max_conversions),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_source_organization_id,'referral_link',x::text,'ReferralLinkCreatedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(p_source_organization_id,'referral.link.create',p_idempotency_key,r);return r;end$$;

create function public.record_referral_touchpoint(p_referral_code text,p_touchpoint_type text,p_visitor_key_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();l public.referral_links%rowtype;h text;cached jsonb;x bigint;r jsonb;begin
 if a is null then raise exception'AUTHENTICATION_REQUIRED'using errcode='42501';end if;select*into l from public.referral_links where referral_code=upper(p_referral_code)and status='ACTIVE'and expires_at>clock_timestamp();if not found then raise exception'ACTIVE_REFERRAL_LINK_REQUIRED'using errcode='P0002';end if;if p_touchpoint_type not in('LINK_OPENED','REGISTRATION_STARTED')or p_visitor_key_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_REFERRAL_TOUCHPOINT'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('link',l.id,'type',p_touchpoint_type,'visitor_hash',p_visitor_key_hash));cached:=private.begin_rewards_command(l.source_organization_id,a,'referral.touchpoint',p_idempotency_key,h);if cached is not null then return cached;end if;insert into public.referral_touchpoints(referral_link_id,source_organization_id,touchpoint_type,visitor_key_hash,correlation_id,actor_user_id)values(l.id,l.source_organization_id,p_touchpoint_type,p_visitor_key_hash,p_correlation_id,a)returning id into x;
 r:=jsonb_build_object('outcome','REFERRAL_TOUCHPOINT_RECORDED','touchpoint_id',x,'touchpoint_type',p_touchpoint_type);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(l.source_organization_id,a,'USER','referral.touchpoint.recorded','referral_touchpoint',x::text,p_correlation_id,jsonb_build_object('referral_link_id',l.id,'touchpoint_type',p_touchpoint_type),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(l.source_organization_id,'referral_link',l.id::text,'ReferralTouchpointRecordedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(l.source_organization_id,'referral.touchpoint',p_idempotency_key,r);return r;end$$;

create function public.register_referral_conversion(p_referral_code text,p_target_organization_id uuid,p_origin_snapshot jsonb,p_evidence_refs jsonb,p_evidence_hash text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();l public.referral_links%rowtype;cnt integer;h text;cached jsonb;x uuid;r jsonb;begin
 if not(private.has_org_role(p_target_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a))then raise exception'REFERRAL_CONVERSION_DENIED'using errcode='42501';end if;select*into l from public.referral_links where referral_code=upper(p_referral_code)and status='ACTIVE'and expires_at>clock_timestamp()for update;if not found then raise exception'ACTIVE_REFERRAL_LINK_REQUIRED'using errcode='P0002';end if;if l.source_organization_id=p_target_organization_id or jsonb_typeof(p_origin_snapshot)<>'object'or jsonb_typeof(p_evidence_refs)<>'array'or jsonb_array_length(p_evidence_refs)=0 or p_evidence_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_REFERRAL_CONVERSION'using errcode='22023';end if;select count(*)into cnt from public.referral_conversions where referral_link_id=l.id;if cnt>=l.max_conversions then raise exception'REFERRAL_CONVERSION_CAP_REACHED'using errcode='23514';end if;
 h:=private.canonical_request_hash(jsonb_build_object('link',l.id,'target',p_target_organization_id,'origin',p_origin_snapshot,'evidence',p_evidence_refs,'evidence_hash',p_evidence_hash));cached:=private.begin_rewards_command(p_target_organization_id,a,'referral.conversion.register',p_idempotency_key,h);if cached is not null then return cached;end if;insert into public.referral_conversions(referral_link_id,source_organization_id,target_organization_id,conversion_stage,origin_snapshot,registered_by)values(l.id,l.source_organization_id,p_target_organization_id,'REGISTERED',p_origin_snapshot,a)returning id into x;insert into public.referral_conversion_events(referral_conversion_id,source_organization_id,from_stage,to_stage,evidence_refs,evidence_hash,correlation_id,actor_user_id)values(x,l.source_organization_id,null,'REGISTERED',p_evidence_refs,p_evidence_hash,p_correlation_id,a);
 r:=jsonb_build_object('outcome','REFERRAL_REGISTERED','referral_conversion_id',x,'conversion_stage','REGISTERED');insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_target_organization_id,a,'USER','referral.conversion.registered','referral_conversion',x::text,p_correlation_id,jsonb_build_object('source_organization_id',l.source_organization_id,'referral_link_id',l.id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_target_organization_id,'referral_conversion',x::text,'ReferralRegisteredV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(p_target_organization_id,'referral.conversion.register',p_idempotency_key,r);return r;end$$;

create function public.advance_referral_conversion(p_referral_conversion_id uuid,p_to_stage text,p_evidence_refs jsonb,p_evidence_hash text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();c public.referral_conversions%rowtype;expected text;h text;cached jsonb;r jsonb;begin
 select*into c from public.referral_conversions where id=p_referral_conversion_id;if not found then raise exception'REFERRAL_CONVERSION_NOT_FOUND'using errcode='P0002';end if;if not(private.has_org_role(c.target_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','PROVIDER_OWNER','PROVIDER_MANAGER'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a))then raise exception'REFERRAL_ADVANCE_DENIED'using errcode='42501';end if;expected:=case c.conversion_stage when'REGISTERED'then'PROFILE_STARTED'when'PROFILE_STARTED'then'VERIFIED'when'VERIFIED'then'ACTIVE'end;if p_to_stage is distinct from expected or p_expected_row_version<>c.row_version or jsonb_typeof(p_evidence_refs)<>'array'or jsonb_array_length(p_evidence_refs)=0 or p_evidence_hash!~'^[0-9a-f]{64}$'then raise exception'INVALID_REFERRAL_TRANSITION'using errcode='55000';end if;
 h:=private.canonical_request_hash(jsonb_build_object('conversion',c.id,'from',c.conversion_stage,'to',p_to_stage,'evidence',p_evidence_refs,'evidence_hash',p_evidence_hash,'expected',p_expected_row_version));cached:=private.begin_rewards_command(c.target_organization_id,a,'referral.conversion.advance',p_idempotency_key,h);if cached is not null then return cached;end if;update public.referral_conversions set conversion_stage=p_to_stage,updated_at=clock_timestamp(),row_version=row_version+1 where id=c.id and row_version=p_expected_row_version;if not found then raise exception'STALE_REFERRAL_CONVERSION'using errcode='40001';end if;insert into public.referral_conversion_events(referral_conversion_id,source_organization_id,from_stage,to_stage,evidence_refs,evidence_hash,correlation_id,actor_user_id)values(c.id,c.source_organization_id,c.conversion_stage,p_to_stage,p_evidence_refs,p_evidence_hash,p_correlation_id,a);
 r:=jsonb_build_object('outcome','REFERRAL_STAGE_ADVANCED','referral_conversion_id',c.id,'conversion_stage',p_to_stage,'row_version',c.row_version+1);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(c.target_organization_id,a,'USER','referral.conversion.advanced','referral_conversion',c.id::text,p_correlation_id,jsonb_build_object('from_stage',c.conversion_stage,'to_stage',p_to_stage,'source_organization_id',c.source_organization_id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(c.target_organization_id,'referral_conversion',c.id::text,case when p_to_stage='VERIFIED'then'ReferralVerifiedV1'when p_to_stage='ACTIVE'then'ReferralActivatedV1'else'ReferralProfileStartedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(c.target_organization_id,'referral.conversion.advance',p_idempotency_key,r);return r;end$$;

create function public.capture_verified_baseline(p_organization_id uuid,p_subject_type text,p_subject_id uuid,p_metric_code text,p_baseline_amount_minor bigint,p_currency text,p_period_start date,p_period_end date,p_source_type text,p_source_reference text,p_evidence_refs jsonb,p_evidence_hash text,p_methodology_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();n integer;h text;cached jsonb;x uuid;r jsonb;begin
 if not(private.has_org_role(p_organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'BASELINE_VERIFY_DENIED'using errcode='42501';end if;if p_subject_type not in('RECOMMENDATION','OPPORTUNITY','SERVICE','PROJECT','CONTRACT','ORGANIZATION')or p_metric_code!~'^[A-Z][A-Z0-9_]{2,63}$'or p_baseline_amount_minor<0 or p_currency!~'^[A-Z]{3}$'or p_period_end<p_period_start or p_source_type not in('INVOICE','CONTRACT','ACCOUNTING_EXPORT','METER_READING','SIGNED_REPORT','AUDITED_IMPORT')or length(btrim(coalesce(p_source_reference,'')))not between 3 and 240 or jsonb_typeof(p_evidence_refs)<>'array'or jsonb_array_length(p_evidence_refs)=0 or p_evidence_hash!~'^[0-9a-f]{64}$'or p_methodology_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'then raise exception'VERIFIABLE_BASELINE_REQUIRED'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('org',p_organization_id,'subject_type',p_subject_type,'subject_id',p_subject_id,'metric',p_metric_code,'amount_minor',p_baseline_amount_minor,'currency',p_currency,'period_start',p_period_start,'period_end',p_period_end,'source_type',p_source_type,'source_reference',p_source_reference,'evidence',p_evidence_refs,'evidence_hash',p_evidence_hash,'methodology',p_methodology_version));cached:=private.begin_rewards_command(p_organization_id,a,'measurement.baseline.capture',p_idempotency_key,h);if cached is not null then return cached;end if;perform pg_advisory_xact_lock(hashtextextended('baseline:'||p_organization_id::text||':'||p_subject_type||':'||p_subject_id::text||':'||p_metric_code,0));select coalesce(max(version_number),0)+1 into n from public.measurement_baselines where organization_id=p_organization_id and subject_type=p_subject_type and subject_id=p_subject_id and metric_code=p_metric_code;insert into public.measurement_baselines(organization_id,subject_type,subject_id,metric_code,version_number,baseline_amount_minor,currency,period_start,period_end,source_type,source_reference,evidence_refs,evidence_hash,methodology_version,verification_status,verified_by,correlation_id)values(p_organization_id,p_subject_type,p_subject_id,p_metric_code,n,p_baseline_amount_minor,p_currency,p_period_start,p_period_end,p_source_type,p_source_reference,p_evidence_refs,p_evidence_hash,p_methodology_version,'VERIFIED',a,p_correlation_id)returning id into x;
 r:=jsonb_build_object('outcome','MEASUREMENT_BASELINE_VERIFIED','baseline_id',x,'version_number',n,'amount_minor',p_baseline_amount_minor,'currency',p_currency);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_organization_id,a,'USER','measurement.baseline.verified','measurement_baseline',x::text,p_correlation_id,jsonb_build_object('subject_type',p_subject_type,'subject_id',p_subject_id,'metric_code',p_metric_code,'source_type',p_source_type,'methodology_version',p_methodology_version),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_organization_id,'measurement_baseline',x::text,'MeasurementBaselineVerifiedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(p_organization_id,'measurement.baseline.capture',p_idempotency_key,r);return r;end$$;

create function public.calculate_recommendation_roi(p_recommendation_id uuid,p_baseline_id uuid,p_actual_amount_minor bigint,p_implementation_cost_minor bigint,p_actual_period_start date,p_actual_period_end date,p_actual_source_type text,p_actual_source_reference text,p_evidence_refs jsonb,p_evidence_hash text,p_formula_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();b public.measurement_baselines%rowtype;rec public.diagnostic_recommendations%rowtype;realized bigint;net bigint;roi bigint;h text;cached jsonb;x uuid;r jsonb;begin
 select*into rec from public.diagnostic_recommendations where id=p_recommendation_id;select*into b from public.measurement_baselines where id=p_baseline_id and verification_status='VERIFIED';if not found or rec.id is null or rec.organization_id<>b.organization_id or b.subject_type<>'RECOMMENDATION'or b.subject_id<>rec.id then raise exception'VERIFIED_RECOMMENDATION_BASELINE_REQUIRED'using errcode='22023';end if;if not(private.has_org_role(b.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'ROI_CALCULATION_DENIED'using errcode='42501';end if;
 if p_actual_amount_minor<0 or p_implementation_cost_minor<=0 or p_actual_period_end<p_actual_period_start or(p_actual_period_end-p_actual_period_start)<>(b.period_end-b.period_start)or p_actual_source_type not in('INVOICE','CONTRACT','ACCOUNTING_EXPORT','METER_READING','SIGNED_REPORT','AUDITED_IMPORT')or length(btrim(coalesce(p_actual_source_reference,'')))not between 3 and 240 or jsonb_typeof(p_evidence_refs)<>'array'or jsonb_array_length(p_evidence_refs)=0 or p_evidence_hash!~'^[0-9a-f]{64}$'or p_formula_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'then raise exception'COMPARABLE_ROI_EVIDENCE_REQUIRED'using errcode='22023';end if;realized:=b.baseline_amount_minor-p_actual_amount_minor;net:=realized-p_implementation_cost_minor;roi:=trunc((net::numeric*10000::numeric)/p_implementation_cost_minor::numeric)::bigint;
 h:=private.canonical_request_hash(jsonb_build_object('recommendation',rec.id,'baseline',b.id,'actual_minor',p_actual_amount_minor,'cost_minor',p_implementation_cost_minor,'period_start',p_actual_period_start,'period_end',p_actual_period_end,'source_type',p_actual_source_type,'source_reference',p_actual_source_reference,'evidence',p_evidence_refs,'evidence_hash',p_evidence_hash,'formula',p_formula_version));cached:=private.begin_rewards_command(b.organization_id,a,'recommendation.roi.calculate',p_idempotency_key,h);if cached is not null then return cached;end if;insert into public.recommendation_roi_snapshots(organization_id,recommendation_id,baseline_id,actual_amount_minor,realized_value_minor,implementation_cost_minor,net_value_minor,roi_basis_points,currency,actual_period_start,actual_period_end,actual_source_type,actual_source_reference,evidence_refs,evidence_hash,formula_version,explanation,calculated_by,correlation_id)values(b.organization_id,rec.id,b.id,p_actual_amount_minor,realized,p_implementation_cost_minor,net,roi,b.currency,p_actual_period_start,p_actual_period_end,p_actual_source_type,p_actual_source_reference,p_evidence_refs,p_evidence_hash,p_formula_version,jsonb_build_object('formula','((baseline_minor-actual_minor)-implementation_cost_minor)*10000/implementation_cost_minor','baseline_minor',b.baseline_amount_minor,'actual_minor',p_actual_amount_minor,'implementation_cost_minor',p_implementation_cost_minor,'verified_baseline_id',b.id,'baseline_methodology_version',b.methodology_version),a,p_correlation_id)returning id into x;
 r:=jsonb_build_object('outcome','RECOMMENDATION_ROI_CALCULATED','roi_snapshot_id',x,'realized_value_minor',realized,'net_value_minor',net,'roi_basis_points',roi,'currency',b.currency);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(b.organization_id,a,'USER','recommendation.roi.calculated','recommendation_roi_snapshot',x::text,p_correlation_id,jsonb_build_object('recommendation_id',rec.id,'baseline_id',b.id,'formula_version',p_formula_version),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(b.organization_id,'recommendation_roi',x::text,'RecommendationRoiCalculatedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(b.organization_id,'recommendation.roi.calculate',p_idempotency_key,r);return r;end$$;

create function public.record_verified_savings(p_baseline_id uuid,p_actual_amount_minor bigint,p_actual_period_start date,p_actual_period_end date,p_source_type text,p_source_reference text,p_evidence_refs jsonb,p_evidence_hash text,p_formula_version text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$declare a uuid:=auth.uid();b public.measurement_baselines%rowtype;s bigint;h text;cached jsonb;x uuid;r jsonb;begin
 select*into b from public.measurement_baselines where id=p_baseline_id and verification_status='VERIFIED';if not found then raise exception'VERIFIED_SAVINGS_BASELINE_REQUIRED'using errcode='22023';end if;if not(private.has_org_role(b.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_ACCOUNTING'],a)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER'],a))then raise exception'SAVINGS_RECORD_DENIED'using errcode='42501';end if;
 if p_actual_amount_minor<0 or p_actual_amount_minor>b.baseline_amount_minor or p_actual_period_end<p_actual_period_start or(p_actual_period_end-p_actual_period_start)<>(b.period_end-b.period_start)or p_source_type not in('INVOICE','CONTRACT','ACCOUNTING_EXPORT','METER_READING','SIGNED_REPORT','AUDITED_IMPORT')or length(btrim(coalesce(p_source_reference,'')))not between 3 and 240 or jsonb_typeof(p_evidence_refs)<>'array'or jsonb_array_length(p_evidence_refs)=0 or p_evidence_hash!~'^[0-9a-f]{64}$'or p_formula_version!~'^[A-Z0-9][A-Z0-9._-]{2,79}$'then raise exception'VERIFIABLE_COMPARABLE_SAVINGS_REQUIRED'using errcode='22023';end if;s:=b.baseline_amount_minor-p_actual_amount_minor;
 h:=private.canonical_request_hash(jsonb_build_object('baseline',b.id,'actual_minor',p_actual_amount_minor,'period_start',p_actual_period_start,'period_end',p_actual_period_end,'source_type',p_source_type,'source_reference',p_source_reference,'evidence',p_evidence_refs,'evidence_hash',p_evidence_hash,'formula',p_formula_version));cached:=private.begin_rewards_command(b.organization_id,a,'savings.record',p_idempotency_key,h);if cached is not null then return cached;end if;insert into public.savings_measurements(organization_id,baseline_id,actual_amount_minor,savings_amount_minor,currency,actual_period_start,actual_period_end,source_type,source_reference,evidence_refs,evidence_hash,formula_version,explanation,recorded_by,correlation_id)values(b.organization_id,b.id,p_actual_amount_minor,s,b.currency,p_actual_period_start,p_actual_period_end,p_source_type,p_source_reference,p_evidence_refs,p_evidence_hash,p_formula_version,jsonb_build_object('formula','baseline_amount_minor-actual_amount_minor','baseline_amount_minor',b.baseline_amount_minor,'actual_amount_minor',p_actual_amount_minor,'verified_baseline_id',b.id,'baseline_methodology_version',b.methodology_version),a,p_correlation_id)returning id into x;
 r:=jsonb_build_object('outcome','VERIFIED_SAVINGS_RECORDED','savings_measurement_id',x,'savings_amount_minor',s,'currency',b.currency);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(b.organization_id,a,'USER','savings.verified_recorded','savings_measurement',x::text,p_correlation_id,jsonb_build_object('baseline_id',b.id,'formula_version',p_formula_version,'source_type',p_source_type),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(b.organization_id,'savings_measurement',x::text,'VerifiedSavingsRecordedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_rewards_command(b.organization_id,'savings.record',p_idempotency_key,r);return r;end$$;

create policy reward_rules_admin_read on public.reward_rule_versions for select to authenticated using(private.credits_admin_access());
create policy reward_grants_tenant_read on public.reward_grants for select to authenticated using(private.credits_client_access(organization_id));
create policy referral_links_source_read on public.referral_links for select to authenticated using(private.is_active_org_member(source_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy referral_touchpoints_source_read on public.referral_touchpoints for select to authenticated using(private.is_active_org_member(source_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy referral_conversions_scoped_read on public.referral_conversions for select to authenticated using(private.is_active_org_member(source_organization_id)or private.is_active_org_member(target_organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy referral_conversion_events_scoped_read on public.referral_conversion_events for select to authenticated using(exists(select 1 from public.referral_conversions c where c.id=referral_conversion_id and(private.is_active_org_member(c.source_organization_id)or private.is_active_org_member(c.target_organization_id)))or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR']));
create policy measurement_baselines_tenant_read on public.measurement_baselines for select to authenticated using(private.is_active_org_member(organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy recommendation_roi_tenant_read on public.recommendation_roi_snapshots for select to authenticated using(private.is_active_org_member(organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
create policy savings_measurements_tenant_read on public.savings_measurements for select to authenticated using(private.is_active_org_member(organization_id)or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','READ_ONLY_AUDITOR']));
grant select on public.reward_rule_versions,public.reward_grants,public.referral_links,public.referral_touchpoints,public.referral_conversions,public.referral_conversion_events,public.measurement_baselines,public.recommendation_roi_snapshots,public.savings_measurements to authenticated;

revoke all on function public.create_reward_rule_version(text,text,text,text,bigint,bigint,bigint,integer,integer,integer,jsonb,boolean,timestamptz,timestamptz,text,text,uuid),public.award_reward(uuid,uuid,uuid,text,text,text,jsonb,text,text,uuid),public.create_referral_link(uuid,text,text,text,timestamptz,integer,text,uuid),public.record_referral_touchpoint(text,text,text,text,uuid),public.register_referral_conversion(text,uuid,jsonb,jsonb,text,text,uuid),public.advance_referral_conversion(uuid,text,jsonb,text,integer,text,uuid),public.capture_verified_baseline(uuid,text,uuid,text,bigint,text,date,date,text,text,jsonb,text,text,text,uuid),public.calculate_recommendation_roi(uuid,uuid,bigint,bigint,date,date,text,text,jsonb,text,text,text,uuid),public.record_verified_savings(uuid,bigint,date,date,text,text,jsonb,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_reward_rule_version(text,text,text,text,bigint,bigint,bigint,integer,integer,integer,jsonb,boolean,timestamptz,timestamptz,text,text,uuid),public.award_reward(uuid,uuid,uuid,text,text,text,jsonb,text,text,uuid),public.create_referral_link(uuid,text,text,text,timestamptz,integer,text,uuid),public.record_referral_touchpoint(text,text,text,text,uuid),public.register_referral_conversion(text,uuid,jsonb,jsonb,text,text,uuid),public.advance_referral_conversion(uuid,text,jsonb,text,integer,text,uuid),public.capture_verified_baseline(uuid,text,uuid,text,bigint,text,date,date,text,text,jsonb,text,text,text,uuid),public.calculate_recommendation_roi(uuid,uuid,bigint,bigint,date,date,text,text,jsonb,text,text,text,uuid),public.record_verified_savings(uuid,bigint,date,date,text,text,jsonb,text,text,text,uuid) to authenticated;
