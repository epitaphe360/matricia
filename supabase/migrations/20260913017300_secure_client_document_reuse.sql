-- MAT-FUNC-012/021/025: consented, tenant-safe reuse of verified Client documents.
-- Bindings and revocations are append-only evidence; binary objects are never copied.

create table public.client_document_bindings(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  document_id uuid not null,
  target_type text not null check(target_type in('SERVICE_REQUEST','CONTRACT_VERSION','MISSION')),
  target_id uuid not null,
  purpose text not null check(length(btrim(purpose)) between 3 and 500),
  document_version integer not null check(document_version>0),
  document_sha256 text not null check(document_sha256~'^[0-9a-f]{64}$'),
  consented_by uuid not null references auth.users(id),
  correlation_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  foreign key(document_id,organization_id) references public.client_compliance_documents(id,organization_id) on delete restrict,
  unique(document_id,target_type,target_id,purpose),unique(id,organization_id)
);
create table public.client_document_binding_revocations(
  id uuid primary key default extensions.gen_random_uuid(),binding_id uuid not null,organization_id uuid not null,
  reason text not null check(length(btrim(reason)) between 3 and 500),revoked_by uuid not null references auth.users(id),
  correlation_id uuid not null,revoked_at timestamptz not null default clock_timestamp(),
  foreign key(binding_id,organization_id) references public.client_document_bindings(id,organization_id) on delete restrict,unique(binding_id)
);
create index client_document_bindings_target_idx on public.client_document_bindings(organization_id,target_type,target_id,created_at desc);
create index client_document_bindings_document_idx on public.client_document_bindings(organization_id,document_id,created_at desc);
alter table public.client_document_bindings enable row level security;
alter table public.client_document_binding_revocations enable row level security;
revoke all on public.client_document_bindings,public.client_document_binding_revocations from public,anon,authenticated,service_role;
grant select on public.client_document_bindings,public.client_document_binding_revocations to authenticated;
create policy client_document_bindings_read on public.client_document_bindings for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],auth.uid())or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'],auth.uid()));
create policy client_document_binding_revocations_read on public.client_document_binding_revocations for select to authenticated using(private.has_org_role(organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],auth.uid())or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR'],auth.uid()));
create trigger client_document_bindings_immutable before update or delete on public.client_document_bindings for each row execute function private.prevent_update_delete();
create trigger client_document_binding_revocations_immutable before update or delete on public.client_document_binding_revocations for each row execute function private.prevent_update_delete();

create function private.client_document_target_organization(p_target_type text,p_target_id uuid)returns uuid language plpgsql stable security definer set search_path=pg_catalog,public as $$
declare result uuid;begin
 case p_target_type
  when'SERVICE_REQUEST'then select client_organization_id into result from public.service_requests where id=p_target_id;
  when'CONTRACT_VERSION'then select c.client_organization_id into result from public.contract_versions v join public.contracts c on c.id=v.contract_id where v.id=p_target_id;
  when'MISSION'then select client_organization_id into result from public.missions where id=p_target_id;
  else return null;
 end case;return result;
end$$;
revoke all on function private.client_document_target_organization(text,uuid)from public,anon,authenticated,service_role;

create function public.link_verified_client_document(p_document_id uuid,p_target_type text,p_target_id uuid,p_purpose text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();d public.client_compliance_documents%rowtype;target_org uuid;h text;cached jsonb;r jsonb;binding uuid;
begin
 if a is null or auth.role()is distinct from'authenticated'or auth.jwt()->>'aal'is distinct from'aal2'then raise exception'CLIENT_DOCUMENT_REUSE_MFA_REQUIRED'using errcode='42501';end if;
 select*into d from public.client_compliance_documents where id=p_document_id;
 if not found or not private.has_org_role(d.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'CLIENT_DOCUMENT_REUSE_DENIED'using errcode='42501';end if;
 target_org:=private.client_document_target_organization(p_target_type,p_target_id);
 if target_org is null or target_org<>d.organization_id then raise exception'CLIENT_DOCUMENT_TARGET_OUTSIDE_TENANT'using errcode='23514';end if;
 if d.status<>'VERIFIED'or d.scan_status<>'CLEAN'or d.current_scan_result_id is null or(d.expires_on is not null and d.expires_on<current_date)or not exists(select 1 from private.client_document_scan_results s where s.id=d.current_scan_result_id and s.document_id=d.id and s.organization_id=d.organization_id and s.result='CLEAN'and s.computed_sha256=d.declared_sha256)or length(btrim(coalesce(p_purpose,'')))not between 3 and 500 then raise exception'CLIENT_DOCUMENT_NOT_REUSABLE'using errcode='55000';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','client.document.reuse.link.v1','document_id',d.id,'target_type',p_target_type,'target_id',p_target_id,'purpose',btrim(p_purpose),'document_version',d.version,'document_sha256',d.declared_sha256));
 cached:=private.begin_contract_command(d.organization_id,'client.document.reuse.link',p_idempotency_key,h,a);if cached is not null then return cached;end if;
 insert into public.client_document_bindings(organization_id,document_id,target_type,target_id,purpose,document_version,document_sha256,consented_by,correlation_id)values(d.organization_id,d.id,p_target_type,p_target_id,btrim(p_purpose),d.version,d.declared_sha256,a,p_correlation_id)returning id into binding;
 r:=jsonb_build_object('outcome','CLIENT_DOCUMENT_LINKED','binding_id',binding,'document_id',d.id,'target_type',p_target_type,'target_id',p_target_id);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(d.organization_id,a,'USER','client.document.reuse.linked','client_document_binding',binding::text,p_correlation_id,jsonb_build_object('document_id',d.id,'target_type',p_target_type,'target_id',p_target_id,'document_version',d.version),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(d.organization_id,'client_document_binding',binding::text,'ClientDocumentLinkedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(d.organization_id,'client.document.reuse.link',p_idempotency_key,r);return r;
exception when unique_violation then raise exception'CLIENT_DOCUMENT_ALREADY_LINKED'using errcode='23505';end$$;

create function public.revoke_client_document_binding(p_binding_id uuid,p_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql security definer set search_path=pg_catalog,public,private,extensions as $$
declare a uuid:=auth.uid();b public.client_document_bindings%rowtype;h text;cached jsonb;r jsonb;revocation uuid;
begin
 select*into b from public.client_document_bindings where id=p_binding_id;
 if a is null or auth.role()is distinct from'authenticated'or auth.jwt()->>'aal'is distinct from'aal2'or not found or not private.has_org_role(b.organization_id,array['CLIENT_OWNER','CLIENT_ADMIN'],a)then raise exception'CLIENT_DOCUMENT_REVOKE_DENIED'using errcode='42501';end if;
 if length(btrim(coalesce(p_reason,'')))not between 3 and 500 then raise exception'INVALID_REVOCATION_REASON'using errcode='22023';end if;
 h:=private.canonical_request_hash(jsonb_build_object('operation','client.document.reuse.revoke.v1','binding_id',b.id,'reason',btrim(p_reason)));
 cached:=private.begin_contract_command(b.organization_id,'client.document.reuse.revoke',p_idempotency_key,h,a);if cached is not null then return cached;end if;
 insert into public.client_document_binding_revocations(binding_id,organization_id,reason,revoked_by,correlation_id)values(b.id,b.organization_id,btrim(p_reason),a,p_correlation_id)returning id into revocation;
 r:=jsonb_build_object('outcome','CLIENT_DOCUMENT_LINK_REVOKED','binding_id',b.id,'revocation_id',revocation);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)values(b.organization_id,a,'USER','client.document.reuse.revoked','client_document_binding',b.id::text,p_correlation_id,jsonb_build_object('revocation_id',revocation,'target_type',b.target_type,'target_id',b.target_id),repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)values(b.organization_id,'client_document_binding',b.id::text,'ClientDocumentLinkRevokedV1',p_correlation_id,r,p_idempotency_key);
 perform private.finish_contract_command(b.organization_id,'client.document.reuse.revoke',p_idempotency_key,r);return r;
exception when unique_violation then raise exception'CLIENT_DOCUMENT_LINK_ALREADY_REVOKED'using errcode='23505';end$$;
revoke all on function public.link_verified_client_document(uuid,text,uuid,text,text,uuid),public.revoke_client_document_binding(uuid,text,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.link_verified_client_document(uuid,text,uuid,text,text,uuid),public.revoke_client_document_binding(uuid,text,text,uuid)to authenticated;
