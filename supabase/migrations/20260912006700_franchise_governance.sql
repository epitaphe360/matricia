-- P13 franchise governance: territories, versioned mandates, invitations and dual-control approvals.

create table public.franchises (
  id uuid primary key default extensions.gen_random_uuid(),
  library_id uuid not null references public.catalog_libraries(id) on delete restrict,
  operator_organization_id uuid not null references public.organizations(id) on delete restrict,
  franchise_type text not null check(franchise_type in('IT','STANDARD')),
  operator_code text not null check(operator_code in('HATIM_AHMITECH','FRANCHISEE')),
  territory_code text not null check(territory_code~'^[A-Z][A-Z0-9_-]{1,31}$'),
  status text not null default 'CONTRACT_PENDING' check(status in('REGISTERED','COMPANY_REVIEW','DOCUMENT_REVIEW','CONTRACT_PENDING','ENTRY_FEE_SETUP','LIBRARY_ASSIGNED','ACTIVE','FINANCIAL_RESTRICTED','SUSPENDED','TERMINATED')),
  current_mandate_version_id uuid,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  unique(id,operator_organization_id),
  check((franchise_type='IT' and operator_code='HATIM_AHMITECH')or(franchise_type='STANDARD' and operator_code='FRANCHISEE'))
);
create unique index franchises_active_library_territory_uidx on public.franchises(library_id,territory_code) where status='ACTIVE';

create table public.franchise_territory_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  version integer not null check(version>0),
  territory_code text not null check(territory_code~'^[A-Z][A-Z0-9_-]{1,31}$'),
  name_fr text not null check(length(btrim(name_fr)) between 2 and 160),
  name_ar text not null check(length(btrim(name_ar)) between 2 and 160),
  scope_snapshot jsonb not null check(jsonb_typeof(scope_snapshot)='object'),
  effective_from timestamptz not null,
  effective_until timestamptz,
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(franchise_id,version), unique(id,franchise_id),
  check(effective_until is null or effective_until>effective_from)
);

create table public.franchise_mandate_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  territory_version_id uuid not null,
  economic_rule_version_id uuid not null references public.franchise_economic_rule_versions(id) on delete restrict,
  version integer not null check(version>0),
  mandate_status text not null check(mandate_status in('PROPOSED','ACTIVE')),
  rights_snapshot jsonb not null check(jsonb_typeof(rights_snapshot)='object'),
  obligations_snapshot jsonb not null check(jsonb_typeof(obligations_snapshot)='object'),
  contract_snapshot jsonb not null check(jsonb_typeof(contract_snapshot)='object'),
  entry_fee_minor bigint not null check(entry_fee_minor>=0),
  entry_fee_mode text not null check(entry_fee_mode in('EXEMPT','UPFRONT','INSTALLMENT','REVENUE_WITHHOLDING')),
  entry_fee_term_months integer not null check(entry_fee_term_months between 0 and 6),
  franchisee_share_bps integer not null check(franchisee_share_bps between 0 and 10000),
  neoxa_share_bps integer not null check(neoxa_share_bps between 0 and 10000),
  matricia_share_bps integer not null check(matricia_share_bps between 0 and 10000),
  distribution_basis text not null check(distribution_basis='DISTRIBUTABLE_PROFIT'),
  effective_from timestamptz not null,
  effective_until timestamptz,
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(franchise_id,version), unique(id,franchise_id),
  foreign key(territory_version_id,franchise_id) references public.franchise_territory_versions(id,franchise_id) on delete restrict,
  check(franchisee_share_bps+neoxa_share_bps+matricia_share_bps=10000),
  check(effective_until is null or effective_until>effective_from)
);
create unique index franchise_mandates_one_active_uidx on public.franchise_mandate_versions(franchise_id) where mandate_status='ACTIVE';
alter table public.franchises add constraint franchises_current_mandate_fk foreign key(current_mandate_version_id,id) references public.franchise_mandate_versions(id,franchise_id) on delete restrict;

create table public.franchise_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  invited_email extensions.citext not null,
  status text not null default 'SENT' check(status in('SENT','ACCEPTED','DECLINED','EXPIRED','REVOKED')),
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id),
  accepted_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  row_version integer not null default 1 check(row_version>0),
  check(expires_at<=created_at+interval'30 days')
);
create table private.franchise_invitation_tokens (
  invitation_id uuid primary key references public.franchise_invitations(id) on delete cascade,
  token_hash text not null unique check(token_hash~'^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp()
);
revoke all on private.franchise_invitation_tokens from public,anon,authenticated,service_role;
create table public.franchise_invitation_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  invitation_id uuid not null references public.franchise_invitations(id) on delete restrict,
  version integer not null check(version>0),
  locale text not null check(locale in('fr-MA','ar-MA')),
  terms_snapshot jsonb not null check(jsonb_typeof(terms_snapshot)='object'),
  content_hash text not null check(content_hash~'^[0-9a-f]{64}$'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default clock_timestamp(),
  unique(invitation_id,version)
);

create table public.franchise_approval_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  mandate_version_id uuid not null,
  request_type text not null check(request_type in('INITIAL_ACTIVATION','MANDATE_REVISION','TERRITORY_REVISION')),
  status text not null default 'PENDING' check(status in('PENDING','APPROVED','REJECTED','CANCELLED')),
  change_reason text not null check(length(btrim(change_reason)) between 3 and 1000),
  requested_by uuid not null references auth.users(id),
  requested_at timestamptz not null default clock_timestamp(),
  decided_at timestamptz,
  row_version integer not null default 1 check(row_version>0),
  foreign key(mandate_version_id,franchise_id) references public.franchise_mandate_versions(id,franchise_id) on delete restrict
);
create unique index franchise_approval_one_pending_uidx on public.franchise_approval_requests(franchise_id) where status='PENDING';
create table public.franchise_approval_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  approval_request_id uuid not null unique references public.franchise_approval_requests(id) on delete restrict,
  decision text not null check(decision in('APPROVE','REJECT')),
  reason text not null check(length(btrim(reason)) between 3 and 1000),
  mandate_content_hash text not null check(mandate_content_hash~'^[0-9a-f]{64}$'),
  decided_by uuid not null references auth.users(id),
  decided_at timestamptz not null default clock_timestamp()
);
create table public.franchise_governance_events (
  id bigint generated always as identity primary key,
  franchise_id uuid not null references public.franchises(id) on delete restrict,
  event_type text not null,
  from_status text,
  to_status text not null,
  actor_user_id uuid not null references auth.users(id),
  correlation_id uuid not null,
  metadata jsonb not null default '{}' check(jsonb_typeof(metadata)='object'),
  occurred_at timestamptz not null default clock_timestamp()
);

create function private.prevent_franchise_history_change() returns trigger language plpgsql set search_path=pg_catalog as $$begin raise exception 'IMMUTABLE_FRANCHISE_HISTORY' using errcode='55000';end$$;
create trigger franchise_territories_immutable before update or delete on public.franchise_territory_versions for each row execute function private.prevent_franchise_history_change();
create trigger franchise_mandates_immutable before update or delete on public.franchise_mandate_versions for each row execute function private.prevent_franchise_history_change();
create trigger franchise_invitation_versions_immutable before update or delete on public.franchise_invitation_versions for each row execute function private.prevent_franchise_history_change();
create trigger franchise_approval_decisions_immutable before update or delete on public.franchise_approval_decisions for each row execute function private.prevent_franchise_history_change();
create trigger franchise_governance_events_immutable before update or delete on public.franchise_governance_events for each row execute function private.prevent_franchise_history_change();

create function private.franchise_access(p_franchise_id uuid,p_actor uuid default auth.uid()) returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(select 1 from public.franchises f where f.id=p_franchise_id and private.is_active_org_member(f.operator_organization_id,p_actor))or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','FINANCE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR'],p_actor)
$$;
revoke all on function private.franchise_access(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.franchise_access(uuid,uuid) to authenticated;

create function public.propose_franchise_governance(p_library_id uuid,p_operator_organization_id uuid,p_operator_code text,p_territory_code text,p_territory_name_fr text,p_territory_name_ar text,p_territory_scope jsonb,p_effective_from timestamptz,p_effective_until timestamptz,p_entry_fee_minor bigint,p_entry_fee_mode text,p_entry_fee_term_months integer,p_rights jsonb,p_obligations jsonb,p_contract_snapshot jsonb,p_invited_email text,p_invitation_token_hash text,p_invitation_locale text,p_invitation_terms jsonb,p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();l public.catalog_libraries%rowtype;t text;rul public.franchise_economic_rule_versions%rowtype;h text;r jsonb;f uuid;tv uuid;mv uuid;iv uuid;ar uuid;
begin
 if a is null or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','LIBRARY_MANAGER'],a)then raise exception 'FRANCHISE_PROPOSAL_DENIED' using errcode='42501';end if;
 select * into l from public.catalog_libraries where id=p_library_id;if not found then raise exception 'FRANCHISE_LIBRARY_NOT_FOUND' using errcode='P0002';end if;t:=case when l.code='IT'then'IT'else'STANDARD'end;
 if p_operator_code<>(case when t='IT'then'HATIM_AHMITECH'else'FRANCHISEE'end)
    or p_territory_code!~'^[A-Z][A-Z0-9_-]{1,31}$'
    or jsonb_typeof(p_territory_scope)<>'object'
    or jsonb_typeof(p_rights)<>'object'
    or jsonb_typeof(p_obligations)<>'object'
    or jsonb_typeof(p_contract_snapshot)<>'object'
    or jsonb_typeof(p_invitation_terms)<>'object'
    or p_invitation_token_hash!~'^[0-9a-f]{64}$'
    or p_invitation_locale not in('fr-MA','ar-MA')
    or(p_effective_until is not null and p_effective_until<=p_effective_from)
    or length(btrim(coalesce(p_change_reason,'')))not between 3 and 1000
 then raise exception 'INVALID_FRANCHISE_PROPOSAL' using errcode='22023';end if;
 if(t='IT'and(p_entry_fee_minor<>0 or p_entry_fee_mode<>'EXEMPT'or p_entry_fee_term_months<>0))or(t='STANDARD'and(p_entry_fee_minor<=0 or p_entry_fee_mode not in('UPFRONT','INSTALLMENT','REVENUE_WITHHOLDING')or(p_entry_fee_mode='UPFRONT'and p_entry_fee_term_months<>0)or(p_entry_fee_mode in('INSTALLMENT','REVENUE_WITHHOLDING')and p_entry_fee_term_months not between 1 and 6)))then raise exception 'INVALID_FRANCHISE_ENTRY_FEE' using errcode='22023';end if;
 select * into rul from public.franchise_economic_rule_versions where franchise_type=t and status='ACTIVE'and effective_from<=p_effective_from::date and(effective_to is null or effective_to>=p_effective_from::date)order by version desc limit 1;if not found then raise exception 'FRANCHISE_ECONOMIC_RULE_MISSING' using errcode='55000';end if;
 h:=private.canonical_request_hash(jsonb_build_object('library',p_library_id,'operator_org',p_operator_organization_id,'operator',p_operator_code,'territory',p_territory_code,'scope',p_territory_scope,'from',p_effective_from,'until',p_effective_until,'fee_minor',p_entry_fee_minor,'fee_mode',p_entry_fee_mode,'fee_months',p_entry_fee_term_months,'rights',p_rights,'obligations',p_obligations,'contract',p_contract_snapshot,'invite_email',lower(p_invited_email),'invite_hash',p_invitation_token_hash,'terms',p_invitation_terms,'reason',p_change_reason));
 r:=private.begin_contract_command(p_operator_organization_id,'franchise.governance.propose',p_idempotency_key,h,a);if r is not null then return r;end if;
 insert into public.franchises(library_id,operator_organization_id,franchise_type,operator_code,territory_code,created_by)values(p_library_id,p_operator_organization_id,t,p_operator_code,p_territory_code,a)returning id into f;
 insert into public.franchise_territory_versions(franchise_id,version,territory_code,name_fr,name_ar,scope_snapshot,effective_from,effective_until,content_hash,created_by)values(f,1,p_territory_code,p_territory_name_fr,p_territory_name_ar,p_territory_scope,p_effective_from,p_effective_until,private.canonical_request_hash(jsonb_build_object('code',p_territory_code,'fr',p_territory_name_fr,'ar',p_territory_name_ar,'scope',p_territory_scope,'from',p_effective_from,'until',p_effective_until)),a)returning id into tv;
 insert into public.franchise_mandate_versions(franchise_id,territory_version_id,economic_rule_version_id,version,mandate_status,rights_snapshot,obligations_snapshot,contract_snapshot,entry_fee_minor,entry_fee_mode,entry_fee_term_months,franchisee_share_bps,neoxa_share_bps,matricia_share_bps,distribution_basis,effective_from,effective_until,content_hash,created_by)values(f,tv,rul.id,1,'PROPOSED',p_rights,p_obligations,p_contract_snapshot,p_entry_fee_minor,p_entry_fee_mode,p_entry_fee_term_months,rul.franchisee_share_bps,rul.neoxa_share_bps,rul.matricia_share_bps,rul.distribution_basis,p_effective_from,p_effective_until,h,a)returning id into mv;
 insert into public.franchise_invitations(franchise_id,invited_email,expires_at)values(f,p_invited_email,clock_timestamp()+interval'30 days')returning id into iv;insert into private.franchise_invitation_tokens(invitation_id,token_hash)values(iv,p_invitation_token_hash);
 insert into public.franchise_invitation_versions(invitation_id,version,locale,terms_snapshot,content_hash,created_by)values(iv,1,p_invitation_locale,p_invitation_terms,private.canonical_request_hash(jsonb_build_object('locale',p_invitation_locale,'terms',p_invitation_terms,'mandate_hash',h)),a);
 insert into public.franchise_approval_requests(franchise_id,mandate_version_id,request_type,change_reason,requested_by)values(f,mv,'INITIAL_ACTIVATION',p_change_reason,a)returning id into ar;
 insert into public.franchise_governance_events(franchise_id,event_type,to_status,actor_user_id,correlation_id,metadata)values(f,'FRANCHISE_PROPOSED','CONTRACT_PENDING',a,p_correlation_id,jsonb_build_object('mandate_version_id',mv,'approval_request_id',ar,'territory_version_id',tv));
 r:=jsonb_build_object('outcome','FRANCHISE_APPROVAL_REQUIRED','franchise_id',f,'mandate_version_id',mv,'approval_request_id',ar,'invitation_id',iv,'franchise_type',t);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(p_operator_organization_id,a,'USER','franchise.governance.proposed','franchise',f::text,p_correlation_id,jsonb_build_object('library_id',p_library_id,'territory_code',p_territory_code,'mandate_hash',h),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(p_operator_organization_id,'franchise',f::text,'FranchiseApprovalRequiredV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(p_operator_organization_id,'franchise.governance.propose',p_idempotency_key,r);return r;
end$$;

create function public.decide_franchise_governance(p_approval_request_id uuid,p_decision text,p_reason text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();q public.franchise_approval_requests%rowtype;f public.franchises%rowtype;m public.franchise_mandate_versions%rowtype;h text;r jsonb;
begin select * into q from public.franchise_approval_requests where id=p_approval_request_id;select * into f from public.franchises where id=q.franchise_id;select * into m from public.franchise_mandate_versions where id=q.mandate_version_id;
 if a is null or not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],a)or a=q.requested_by then raise exception 'FRANCHISE_APPROVAL_DENIED' using errcode='42501';end if;if p_decision not in('APPROVE','REJECT')or length(btrim(coalesce(p_reason,'')))not between 3 and 1000 then raise exception 'INVALID_FRANCHISE_DECISION' using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('request',q.id,'decision',p_decision,'reason',p_reason,'expected',p_expected_row_version,'mandate_hash',m.content_hash));r:=private.begin_contract_command(f.operator_organization_id,'franchise.governance.decide.'||q.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 update public.franchise_approval_requests set status=case p_decision when'APPROVE'then'APPROVED'else'REJECTED'end,decided_at=clock_timestamp(),row_version=row_version+1 where id=q.id and status='PENDING'and row_version=p_expected_row_version;if not found then raise exception 'STALE_FRANCHISE_APPROVAL' using errcode='40001';end if;
 insert into public.franchise_approval_decisions(approval_request_id,decision,reason,mandate_content_hash,decided_by)values(q.id,p_decision,p_reason,m.content_hash,a);
 update public.franchises set status=case p_decision when'APPROVE'then'LIBRARY_ASSIGNED'else'TERMINATED'end,updated_at=clock_timestamp(),row_version=row_version+1 where id=f.id;
 insert into public.franchise_governance_events(franchise_id,event_type,from_status,to_status,actor_user_id,correlation_id,metadata)values(f.id,'CENTRAL_DECISION',f.status,case p_decision when'APPROVE'then'LIBRARY_ASSIGNED'else'TERMINATED'end,a,p_correlation_id,jsonb_build_object('approval_request_id',q.id,'decision',p_decision,'mandate_hash',m.content_hash));
 r:=jsonb_build_object('outcome',case p_decision when'APPROVE'then'FRANCHISE_APPROVED'else'FRANCHISE_REJECTED'end,'franchise_id',f.id,'approval_request_id',q.id,'row_version',f.row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(f.operator_organization_id,a,'USER','franchise.governance.decided','franchise',f.id::text,p_correlation_id,jsonb_build_object('decision',p_decision,'reason',p_reason,'mandate_hash',m.content_hash),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(f.operator_organization_id,'franchise',f.id::text,case p_decision when'APPROVE'then'FranchiseApprovedV1'else'FranchiseRejectedV1'end,p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(f.operator_organization_id,'franchise.governance.decide.'||q.id::text,p_idempotency_key,r);return r;
end$$;

create function public.accept_franchise_invitation(p_invitation_id uuid,p_token_hash text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();i public.franchise_invitations%rowtype;f public.franchises%rowtype;m public.franchise_mandate_versions%rowtype;h text;r jsonb;active_m uuid;
begin select * into i from public.franchise_invitations where id=p_invitation_id;select * into f from public.franchises where id=i.franchise_id;
 if a is null or not found or not private.has_org_role(f.operator_organization_id,array['FRANCHISE_OWNER'],a)then raise exception 'FRANCHISE_INVITATION_ACCEPT_DENIED' using errcode='42501';end if;if p_token_hash!~'^[0-9a-f]{64}$'then raise exception 'INVALID_FRANCHISE_INVITATION_TOKEN' using errcode='22023';end if;
 select mv.* into m from public.franchise_mandate_versions mv join public.franchise_approval_requests q on q.mandate_version_id=mv.id where q.franchise_id=f.id and q.status='APPROVED'order by q.decided_at desc limit 1;if not found then raise exception 'FRANCHISE_CENTRAL_APPROVAL_REQUIRED' using errcode='55000';end if;
 h:=private.canonical_request_hash(jsonb_build_object('invitation',i.id,'token_hash',p_token_hash,'expected',p_expected_row_version,'mandate_hash',m.content_hash));r:=private.begin_contract_command(f.operator_organization_id,'franchise.invitation.accept.'||i.id::text,p_idempotency_key,h,a);if r is not null then return r;end if;
 update public.franchise_invitations set status='ACCEPTED',accepted_by=a,accepted_at=clock_timestamp(),row_version=row_version+1 where id=i.id and status='SENT'and expires_at>clock_timestamp()and row_version=p_expected_row_version and exists(select 1 from private.franchise_invitation_tokens t where t.invitation_id=i.id and t.token_hash=p_token_hash);if not found then raise exception 'STALE_OR_EXPIRED_FRANCHISE_INVITATION' using errcode='40001';end if;
 insert into public.franchise_mandate_versions(franchise_id,territory_version_id,economic_rule_version_id,version,mandate_status,rights_snapshot,obligations_snapshot,contract_snapshot,entry_fee_minor,entry_fee_mode,entry_fee_term_months,franchisee_share_bps,neoxa_share_bps,matricia_share_bps,distribution_basis,effective_from,effective_until,content_hash,created_by)values(m.franchise_id,m.territory_version_id,m.economic_rule_version_id,m.version+1,'ACTIVE',m.rights_snapshot,m.obligations_snapshot,m.contract_snapshot,m.entry_fee_minor,m.entry_fee_mode,m.entry_fee_term_months,m.franchisee_share_bps,m.neoxa_share_bps,m.matricia_share_bps,m.distribution_basis,greatest(m.effective_from,clock_timestamp()),m.effective_until,m.content_hash,a)returning id into active_m;
 update public.franchises set status='ACTIVE',current_mandate_version_id=active_m,updated_at=clock_timestamp(),row_version=row_version+1 where id=f.id and status='LIBRARY_ASSIGNED';if not found then raise exception 'STALE_FRANCHISE_STATE' using errcode='40001';end if;
 insert into public.franchise_governance_events(franchise_id,event_type,from_status,to_status,actor_user_id,correlation_id,metadata)values(f.id,'INVITATION_ACCEPTED','LIBRARY_ASSIGNED','ACTIVE',a,p_correlation_id,jsonb_build_object('invitation_id',i.id,'active_mandate_version_id',active_m));
 r:=jsonb_build_object('outcome','FRANCHISE_ACTIVATED','franchise_id',f.id,'active_mandate_version_id',active_m,'row_version',f.row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(f.operator_organization_id,a,'USER','franchise.activated','franchise',f.id::text,p_correlation_id,jsonb_build_object('invitation_id',i.id,'mandate_version_id',active_m,'economic_rule_version_id',m.economic_rule_version_id),repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(f.operator_organization_id,'franchise',f.id::text,'FranchiseActivatedV1',p_correlation_id,r,p_idempotency_key);perform private.finish_contract_command(f.operator_organization_id,'franchise.invitation.accept.'||i.id::text,p_idempotency_key,r);return r;
end$$;

alter table public.franchises enable row level security;alter table public.franchise_territory_versions enable row level security;alter table public.franchise_mandate_versions enable row level security;alter table public.franchise_invitations enable row level security;alter table public.franchise_invitation_versions enable row level security;alter table public.franchise_approval_requests enable row level security;alter table public.franchise_approval_decisions enable row level security;alter table public.franchise_governance_events enable row level security;
revoke all on public.franchises,public.franchise_territory_versions,public.franchise_mandate_versions,public.franchise_invitations,public.franchise_invitation_versions,public.franchise_approval_requests,public.franchise_approval_decisions,public.franchise_governance_events from anon,authenticated,service_role;
grant select on public.franchises,public.franchise_territory_versions,public.franchise_mandate_versions,public.franchise_invitations,public.franchise_invitation_versions,public.franchise_approval_requests,public.franchise_approval_decisions,public.franchise_governance_events to authenticated;
create policy franchises_scoped_read on public.franchises for select to authenticated using(private.franchise_access(id));
create policy franchise_territories_scoped_read on public.franchise_territory_versions for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_mandates_scoped_read on public.franchise_mandate_versions for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_invitations_scoped_read on public.franchise_invitations for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_invitation_versions_scoped_read on public.franchise_invitation_versions for select to authenticated using(exists(select 1 from public.franchise_invitations i where i.id=invitation_id and private.franchise_access(i.franchise_id)));
create policy franchise_approval_requests_scoped_read on public.franchise_approval_requests for select to authenticated using(private.franchise_access(franchise_id));
create policy franchise_approval_decisions_scoped_read on public.franchise_approval_decisions for select to authenticated using(exists(select 1 from public.franchise_approval_requests q where q.id=approval_request_id and private.franchise_access(q.franchise_id)));
create policy franchise_governance_events_scoped_read on public.franchise_governance_events for select to authenticated using(private.franchise_access(franchise_id));
create index franchise_territory_history_idx on public.franchise_territory_versions(franchise_id,version desc);create index franchise_mandate_history_idx on public.franchise_mandate_versions(franchise_id,version desc);create index franchise_approval_status_idx on public.franchise_approval_requests(status,requested_at);create index franchise_invitation_expiry_idx on public.franchise_invitations(expires_at)where status='SENT';create index franchise_governance_events_idx on public.franchise_governance_events(franchise_id,occurred_at desc,id desc);
revoke all on function public.propose_franchise_governance(uuid,uuid,text,text,text,text,jsonb,timestamptz,timestamptz,bigint,text,integer,jsonb,jsonb,jsonb,text,text,text,jsonb,text,text,uuid),public.decide_franchise_governance(uuid,text,text,integer,text,uuid),public.accept_franchise_invitation(uuid,text,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.propose_franchise_governance(uuid,uuid,text,text,text,text,jsonb,timestamptz,timestamptz,bigint,text,integer,jsonb,jsonb,jsonb,text,text,text,jsonb,text,text,uuid),public.decide_franchise_governance(uuid,text,text,integer,text,uuid),public.accept_franchise_invitation(uuid,text,integer,text,uuid) to authenticated;
notify pgrst,'reload schema';
