-- P06 hierarchy command API.
-- Signatures intentionally expose complete version payloads, optimistic versions,
-- idempotency keys and correlations; authenticated tables remain read-only.

alter table public.catalog_command_keys
  add column command_id uuid not null default extensions.gen_random_uuid();
alter table public.catalog_command_keys
  add constraint catalog_command_keys_command_id_key unique(command_id);

create function private.begin_catalog_command(
  p_actor uuid,p_scope text,p_key text,p_request_hash text
) returns table(command_id uuid,response_body jsonb)
language plpgsql security definer set search_path=pg_catalog as $$
declare v_key public.catalog_command_keys%rowtype;
begin
 if p_actor is null or coalesce(length(p_key),0) not between 8 and 200 or p_request_hash!~'^[0-9a-f]{64}$' then
  raise exception 'INVALID_CATALOG_COMMAND' using errcode='22023';
 end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-command:'||p_actor::text||':'||p_scope||':'||p_key,0));
 select * into v_key from public.catalog_command_keys where actor_user_id=p_actor and operation_scope=p_scope and key=p_key;
 if found then
  if v_key.request_hash<>p_request_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;
  if v_key.response_body is null then raise exception 'IDEMPOTENCY_IN_PROGRESS' using errcode='55000';end if;
  return query select v_key.command_id,v_key.response_body;return;
 end if;
 insert into public.catalog_command_keys(actor_user_id,operation_scope,key,request_hash)
 values(p_actor,p_scope,p_key,p_request_hash) returning catalog_command_keys.command_id into v_key.command_id;
 return query select v_key.command_id,null::jsonb;
end$$;

create function private.finish_catalog_command(p_actor uuid,p_scope text,p_key text,p_response jsonb) returns void
language plpgsql security definer set search_path=pg_catalog as $$
begin
 update public.catalog_command_keys set response_body=p_response,completed_at=clock_timestamp()
 where actor_user_id=p_actor and operation_scope=p_scope and key=p_key and response_body is null;
 if not found then raise exception 'CATALOG_COMMAND_COMPLETION_FAILED' using errcode='55000';end if;
end$$;

create function private.assert_catalog_central_aal2_locked(p_actor uuid) returns void
language plpgsql security definer set search_path=pg_catalog,private as $$
begin
 if p_actor is null or auth.role() is distinct from 'authenticated' or auth.jwt()->>'aal' is distinct from 'aal2' then
  raise exception 'CENTRAL_MFA_REQUIRED' using errcode='42501';
 end if;
 perform 1 from public.platform_user_roles r where r.user_id=p_actor and r.role_code in ('SUPER_ADMIN','MATRICIA_ADMIN') and r.revoked_at is null for share;
 if not found or not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN'],p_actor) then raise exception 'CENTRAL_MFA_REQUIRED' using errcode='42501';end if;
end$$;

create function private.assert_catalog_permission_locked(p_library_id uuid,p_permission text,p_actor uuid) returns void
language plpgsql security definer set search_path=pg_catalog,private as $$
begin
 perform 1 from public.catalog_libraries l join public.organizations o on o.id=l.steward_organization_id
  where l.id=p_library_id and o.status='ACTIVE' for share of l,o;
 if not found then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 perform 1 from public.platform_user_roles r join public.catalog_permission_policies p on p.role_code=r.role_code
  where r.user_id=p_actor and r.revoked_at is null and p.permission_code=p_permission and p.active
   and statement_timestamp()>=p.valid_from and (p.valid_until is null or statement_timestamp()<p.valid_until) for share of r,p;
 perform 1 from public.organization_memberships m join public.organizations o on o.id=m.organization_id
  join public.organization_member_roles r on r.membership_id=m.id
  join public.catalog_permission_policies p on p.role_code=r.role_code
  join public.catalog_library_mandates x on x.library_id=p_library_id and x.organization_id=m.organization_id
  where m.user_id=p_actor and m.status='ACTIVE' and o.status='ACTIVE' and r.revoked_at is null and r.library_id=p_library_id
   and p.permission_code=p_permission and p.policy_version=x.policy_version and p.active
   and statement_timestamp()>=p.valid_from and (p.valid_until is null or statement_timestamp()<p.valid_until)
   and x.status='ACTIVE' and statement_timestamp()>=x.valid_from and (x.valid_until is null or statement_timestamp()<x.valid_until)
  for share of m,o,r,p,x;
 if p_actor is null or not private.has_library_permission(p_library_id,p_permission,p_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
end$$;
revoke all on function private.begin_catalog_command(uuid,text,text,text),private.finish_catalog_command(uuid,text,text,jsonb),private.assert_catalog_central_aal2_locked(uuid),private.assert_catalog_permission_locked(uuid,text,uuid) from public,anon,authenticated,service_role;

create function public.create_catalog_library(
 p_steward_organization_id uuid,p_code text,p_slug text,p_name_fr text,p_name_ar text,
 p_description_fr text,p_description_ar text,p_icon_key text,p_sort_order integer,p_sensitive boolean,
 p_change_reason text,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_hash text;v_command uuid;v_replay jsonb;v_library uuid;v_version uuid;v_content_hash text;v_response jsonb;
begin
 perform private.assert_catalog_central_aal2_locked(v_actor);
 if p_steward_organization_id is null or p_sort_order is null or p_sort_order<1 or p_sensitive is null then raise exception 'INVALID_CATALOG_LIBRARY' using errcode='22023';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.library.create.v1','steward',p_steward_organization_id,'code',btrim(p_code),'slug',btrim(p_slug),'name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',btrim(p_icon_key),'sort_order',p_sort_order,'sensitive',p_sensitive,'change_reason',btrim(p_change_reason)));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.library.create',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-organization:'||p_steward_organization_id::text,0));perform 1 from public.organizations where id=p_steward_organization_id and status='ACTIVE' for share;if not found then raise exception 'ACTIVE_STEWARD_ORGANIZATION_REQUIRED' using errcode='23514';end if;perform private.assert_catalog_central_aal2_locked(v_actor);
 if v_replay is not null then return v_replay;end if;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',btrim(p_icon_key),'sort_order',p_sort_order,'sensitive',p_sensitive));
 insert into public.catalog_libraries(code,slug,steward_organization_id,created_by) values(btrim(p_code),btrim(p_slug),p_steward_organization_id,v_actor) returning id into v_library;
 insert into public.catalog_library_versions(library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,sensitive,created_by)
 values(v_library,1,'DRAFT',btrim(p_name_fr),btrim(p_name_ar),btrim(p_description_fr),btrim(p_description_ar),btrim(p_icon_key),p_sort_order,btrim(p_change_reason),v_content_hash,p_sensitive,v_actor) returning id into v_version;
 update public.catalog_libraries set current_draft_version_id=v_version where id=v_library;
 insert into public.catalog_library_mandates(library_id,organization_id,status,valid_from,policy_version,created_by) values(v_library,p_steward_organization_id,'ACTIVE',statement_timestamp(),1,v_actor);
 v_response:=jsonb_build_object('outcome','CATALOG_LIBRARY_CREATED','library_id',v_library,'version_id',v_version,'identity_row_version',1,'version_row_version',1,'content_hash',v_content_hash,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(p_steward_organization_id,v_actor,'USER','catalog.library.created','catalog_library',v_library::text,p_correlation_id,jsonb_build_object('version_id',v_version,'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(p_steward_organization_id,'catalog_library',v_library::text,'CatalogLibraryCreatedV1',p_correlation_id,jsonb_build_object('library_id',v_library,'version_id',v_version),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.library.create',p_idempotency_key,v_response);return v_response;
end$$;

create function public.save_catalog_library_draft(
 p_library_id uuid,p_version_id uuid,p_name_fr text,p_name_ar text,p_description_fr text,p_description_ar text,
 p_icon_key text,p_sort_order integer,p_sensitive boolean,p_change_reason text,p_expected_identity_row_version integer,
 p_expected_version_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_identity public.catalog_libraries%rowtype;v_old public.catalog_library_versions%rowtype;v_hash text;v_content_hash text;v_command uuid;v_replay jsonb;v_version uuid;v_number integer;v_response jsonb;
begin
 select * into v_identity from public.catalog_libraries where id=p_library_id;if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode='P0002';end if;
 if p_expected_identity_row_version is null or p_expected_identity_row_version<1 or p_expected_version_row_version is null or p_expected_version_row_version<1 or p_sort_order is null or p_sort_order<1 or p_sensitive is null then raise exception 'INVALID_CATALOG_VERSION' using errcode='22023';end if;
 if v_actor is null or not private.has_library_permission(p_library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.library.save.v1','library_id',p_library_id,'version_id',p_version_id,'name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',btrim(p_icon_key),'sort_order',p_sort_order,'sensitive',p_sensitive,'change_reason',btrim(p_change_reason),'expected_identity',p_expected_identity_row_version,'expected_version',p_expected_version_row_version));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.library.save',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0));select * into v_identity from public.catalog_libraries where id=p_library_id for update;
 select * into v_old from public.catalog_library_versions where id=p_version_id and library_id=p_library_id for update;
 if not found then raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode='P0002';end if;
 perform private.assert_catalog_permission_locked(p_library_id,'CATALOG_EDIT',v_actor);
 if v_replay is not null then return v_replay;end if;
 if v_identity.row_version is distinct from p_expected_identity_row_version or v_old.row_version is distinct from p_expected_version_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',btrim(p_icon_key),'sort_order',p_sort_order,'sensitive',p_sensitive));
 if v_old.status='DRAFT' then
  update public.catalog_library_versions set name_fr=btrim(p_name_fr),name_ar=btrim(p_name_ar),description_fr=btrim(p_description_fr),description_ar=btrim(p_description_ar),icon_key=btrim(p_icon_key),sort_order=p_sort_order,sensitive=p_sensitive,change_reason=btrim(p_change_reason),content_hash=v_content_hash,row_version=row_version+1 where id=p_version_id returning id into v_version;
 else
  select coalesce(max(version),0)+1 into v_number from public.catalog_library_versions where library_id=p_library_id;
  insert into public.catalog_library_versions(library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,change_reason,content_hash,sensitive,created_by) values(p_library_id,v_number,'DRAFT',btrim(p_name_fr),btrim(p_name_ar),btrim(p_description_fr),btrim(p_description_ar),btrim(p_icon_key),p_sort_order,btrim(p_change_reason),v_content_hash,p_sensitive,v_actor) returning id into v_version;
 end if;
 update public.catalog_libraries set current_draft_version_id=v_version,updated_at=clock_timestamp(),row_version=row_version+1 where id=p_library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_LIBRARY_DRAFT_SAVED','library_id',p_library_id,'version_id',v_version,'identity_row_version',p_expected_identity_row_version+1,'version_row_version',case when v_old.status='DRAFT' then p_expected_version_row_version+1 else 1 end,'content_hash',v_content_hash,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_identity.steward_organization_id,v_actor,'USER','catalog.library.draft_saved','catalog_library',p_library_id::text,p_correlation_id,jsonb_build_object('source_version_id',p_version_id,'version_id',v_version,'new_version',v_old.status<>'DRAFT','command_id',v_command),v_old.content_hash,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_identity.steward_organization_id,'catalog_library',p_library_id::text,'CatalogLibraryDraftSavedV1',p_correlation_id,jsonb_build_object('library_id',p_library_id,'version_id',v_version,'new_version',v_old.status<>'DRAFT'),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.library.save',p_idempotency_key,v_response);return v_response;
end$$;

create function public.create_catalog_category(
 p_library_id uuid,p_code text,p_slug text,p_name_fr text,p_name_ar text,p_description_fr text,p_description_ar text,
 p_icon_key text,p_sort_order integer,p_visibility_rules jsonb,p_sensitive boolean,p_change_reason text,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_library public.catalog_libraries%rowtype;v_hash text;v_content_hash text;v_command uuid;v_replay jsonb;v_id uuid;v_version uuid;v_response jsonb;
begin
 select * into v_library from public.catalog_libraries where id=p_library_id;if not found then raise exception 'CATALOG_LIBRARY_NOT_FOUND' using errcode='P0002';end if;
 if p_sort_order is null or p_sort_order<1 or p_visibility_rules is null or jsonb_typeof(p_visibility_rules)<>'object' or p_sensitive is null then raise exception 'INVALID_CATALOG_VERSION' using errcode='22023';end if;
 if v_actor is null or not private.has_library_permission(p_library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.category.create.v1','library_id',p_library_id,'code',btrim(p_code),'slug',btrim(p_slug),'name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive,'change_reason',btrim(p_change_reason)));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.category.create',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-library:'||p_library_id::text,0));select * into v_library from public.catalog_libraries where id=p_library_id for update;perform private.assert_catalog_permission_locked(p_library_id,'CATALOG_EDIT',v_actor);
 if v_replay is not null then return v_replay;end if;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive));
 insert into public.catalog_categories(library_id,code,slug,created_by) values(p_library_id,btrim(p_code),btrim(p_slug),v_actor) returning id into v_id;
 insert into public.catalog_category_versions(category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,change_reason,content_hash,sensitive,created_by) values(v_id,p_library_id,1,'DRAFT',btrim(p_name_fr),btrim(p_name_ar),btrim(p_description_fr),btrim(p_description_ar),case when p_icon_key is null then null else btrim(p_icon_key) end,p_sort_order,p_visibility_rules,btrim(p_change_reason),v_content_hash,p_sensitive,v_actor) returning id into v_version;
 update public.catalog_categories set current_draft_version_id=v_version where id=v_id;
 v_response:=jsonb_build_object('outcome','CATALOG_CATEGORY_CREATED','category_id',v_id,'library_id',p_library_id,'version_id',v_version,'identity_row_version',1,'version_row_version',1,'content_hash',v_content_hash,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_library.steward_organization_id,v_actor,'USER','catalog.category.created','catalog_category',v_id::text,p_correlation_id,jsonb_build_object('library_id',p_library_id,'version_id',v_version,'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_library.steward_organization_id,'catalog_category',v_id::text,'CatalogCategoryCreatedV1',p_correlation_id,jsonb_build_object('category_id',v_id,'library_id',p_library_id,'version_id',v_version),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.category.create',p_idempotency_key,v_response);return v_response;
end$$;

create function public.save_catalog_category_draft(
 p_category_id uuid,p_version_id uuid,p_name_fr text,p_name_ar text,p_description_fr text,p_description_ar text,p_icon_key text,
 p_sort_order integer,p_visibility_rules jsonb,p_sensitive boolean,p_change_reason text,p_expected_identity_row_version integer,
 p_expected_version_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_identity public.catalog_categories%rowtype;v_old public.catalog_category_versions%rowtype;v_org uuid;v_hash text;v_content_hash text;v_command uuid;v_replay jsonb;v_version uuid;v_number integer;v_response jsonb;
begin
 select * into v_identity from public.catalog_categories where id=p_category_id;if not found then raise exception 'CATALOG_CATEGORY_NOT_FOUND' using errcode='P0002';end if;
 if p_expected_identity_row_version is null or p_expected_identity_row_version<1 or p_expected_version_row_version is null or p_expected_version_row_version<1 or p_sort_order is null or p_sort_order<1 or p_visibility_rules is null or jsonb_typeof(p_visibility_rules)<>'object' or p_sensitive is null then raise exception 'INVALID_CATALOG_VERSION' using errcode='22023';end if;
 if v_actor is null or not private.has_library_permission(v_identity.library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.category.save.v1','category_id',p_category_id,'version_id',p_version_id,'name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive,'change_reason',btrim(p_change_reason),'expected_identity',p_expected_identity_row_version,'expected_version',p_expected_version_row_version));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.category.save',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-category:'||p_category_id::text,0));select * into v_identity from public.catalog_categories where id=p_category_id for update;select * into v_old from public.catalog_category_versions where id=p_version_id and category_id=p_category_id for update;
 if not found then raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode='P0002';end if;perform private.assert_catalog_permission_locked(v_identity.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;if v_identity.row_version is distinct from p_expected_identity_row_version or v_old.row_version is distinct from p_expected_version_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive));
 if v_old.status='DRAFT' then update public.catalog_category_versions set name_fr=btrim(p_name_fr),name_ar=btrim(p_name_ar),description_fr=btrim(p_description_fr),description_ar=btrim(p_description_ar),icon_key=case when p_icon_key is null then null else btrim(p_icon_key) end,sort_order=p_sort_order,visibility_rules=p_visibility_rules,sensitive=p_sensitive,change_reason=btrim(p_change_reason),content_hash=v_content_hash,row_version=row_version+1 where id=p_version_id returning id into v_version;
 else select coalesce(max(version),0)+1 into v_number from public.catalog_category_versions where category_id=p_category_id;insert into public.catalog_category_versions(category_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,change_reason,content_hash,sensitive,created_by) values(p_category_id,v_identity.library_id,v_number,'DRAFT',btrim(p_name_fr),btrim(p_name_ar),btrim(p_description_fr),btrim(p_description_ar),case when p_icon_key is null then null else btrim(p_icon_key) end,p_sort_order,p_visibility_rules,btrim(p_change_reason),v_content_hash,p_sensitive,v_actor) returning id into v_version;end if;
 update public.catalog_categories set current_draft_version_id=v_version,row_version=row_version+1 where id=p_category_id;select steward_organization_id into v_org from public.catalog_libraries where id=v_identity.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_CATEGORY_DRAFT_SAVED','category_id',p_category_id,'library_id',v_identity.library_id,'version_id',v_version,'identity_row_version',p_expected_identity_row_version+1,'version_row_version',case when v_old.status='DRAFT' then p_expected_version_row_version+1 else 1 end,'content_hash',v_content_hash,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.category.draft_saved','catalog_category',p_category_id::text,p_correlation_id,jsonb_build_object('source_version_id',p_version_id,'version_id',v_version,'new_version',v_old.status<>'DRAFT','command_id',v_command),v_old.content_hash,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_category',p_category_id::text,'CatalogCategoryDraftSavedV1',p_correlation_id,jsonb_build_object('category_id',p_category_id,'version_id',v_version,'new_version',v_old.status<>'DRAFT'),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.category.save',p_idempotency_key,v_response);return v_response;
end$$;

create function public.create_catalog_subcategory(
 p_category_id uuid,p_code text,p_slug text,p_name_fr text,p_name_ar text,p_description_fr text,p_description_ar text,
 p_icon_key text,p_sort_order integer,p_visibility_rules jsonb,p_sensitive boolean,p_change_reason text,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_parent public.catalog_categories%rowtype;v_org uuid;v_hash text;v_content_hash text;v_command uuid;v_replay jsonb;v_id uuid;v_version uuid;v_response jsonb;
begin
 select * into v_parent from public.catalog_categories where id=p_category_id;if not found then raise exception 'CATALOG_CATEGORY_NOT_FOUND' using errcode='P0002';end if;if p_sort_order is null or p_sort_order<1 or p_visibility_rules is null or jsonb_typeof(p_visibility_rules)<>'object' or p_sensitive is null then raise exception 'INVALID_CATALOG_VERSION' using errcode='22023';end if;
 if v_actor is null or not private.has_library_permission(v_parent.library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.subcategory.create.v1','category_id',p_category_id,'code',btrim(p_code),'slug',btrim(p_slug),'name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive,'change_reason',btrim(p_change_reason)));select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.subcategory.create',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-category:'||p_category_id::text,0));select * into v_parent from public.catalog_categories where id=p_category_id for update;perform private.assert_catalog_permission_locked(v_parent.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;v_content_hash:=private.canonical_request_hash(jsonb_build_object('name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive));
 insert into public.catalog_subcategories(library_id,category_id,code,slug,created_by) values(v_parent.library_id,p_category_id,btrim(p_code),btrim(p_slug),v_actor) returning id into v_id;
 insert into public.catalog_subcategory_versions(subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,change_reason,content_hash,sensitive,created_by) values(v_id,v_parent.library_id,1,'DRAFT',btrim(p_name_fr),btrim(p_name_ar),btrim(p_description_fr),btrim(p_description_ar),case when p_icon_key is null then null else btrim(p_icon_key) end,p_sort_order,p_visibility_rules,btrim(p_change_reason),v_content_hash,p_sensitive,v_actor) returning id into v_version;update public.catalog_subcategories set current_draft_version_id=v_version where id=v_id;select steward_organization_id into v_org from public.catalog_libraries where id=v_parent.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_SUBCATEGORY_CREATED','subcategory_id',v_id,'category_id',p_category_id,'library_id',v_parent.library_id,'version_id',v_version,'identity_row_version',1,'version_row_version',1,'content_hash',v_content_hash,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.subcategory.created','catalog_subcategory',v_id::text,p_correlation_id,jsonb_build_object('category_id',p_category_id,'version_id',v_version,'command_id',v_command),null,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_subcategory',v_id::text,'CatalogSubcategoryCreatedV1',p_correlation_id,jsonb_build_object('subcategory_id',v_id,'category_id',p_category_id,'version_id',v_version),p_idempotency_key,v_command);perform private.finish_catalog_command(v_actor,'catalog.subcategory.create',p_idempotency_key,v_response);return v_response;
end$$;

create function public.save_catalog_subcategory_draft(
 p_subcategory_id uuid,p_version_id uuid,p_name_fr text,p_name_ar text,p_description_fr text,p_description_ar text,p_icon_key text,
 p_sort_order integer,p_visibility_rules jsonb,p_sensitive boolean,p_change_reason text,p_expected_identity_row_version integer,
 p_expected_version_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_identity public.catalog_subcategories%rowtype;v_old public.catalog_subcategory_versions%rowtype;v_org uuid;v_hash text;v_content_hash text;v_command uuid;v_replay jsonb;v_version uuid;v_number integer;v_response jsonb;
begin
 select * into v_identity from public.catalog_subcategories where id=p_subcategory_id;if not found then raise exception 'CATALOG_SUBCATEGORY_NOT_FOUND' using errcode='P0002';end if;if p_expected_identity_row_version is null or p_expected_identity_row_version<1 or p_expected_version_row_version is null or p_expected_version_row_version<1 or p_sort_order is null or p_sort_order<1 or p_visibility_rules is null or jsonb_typeof(p_visibility_rules)<>'object' or p_sensitive is null then raise exception 'INVALID_CATALOG_VERSION' using errcode='22023';end if;
 if v_actor is null or not private.has_library_permission(v_identity.library_id,'CATALOG_EDIT',v_actor) then raise exception 'CATALOG_SCOPE_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.subcategory.save.v1','subcategory_id',p_subcategory_id,'version_id',p_version_id,'name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive,'change_reason',btrim(p_change_reason),'expected_identity',p_expected_identity_row_version,'expected_version',p_expected_version_row_version));select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.subcategory.save',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-subcategory:'||p_subcategory_id::text,0));select * into v_identity from public.catalog_subcategories where id=p_subcategory_id for update;select * into v_old from public.catalog_subcategory_versions where id=p_version_id and subcategory_id=p_subcategory_id for update;if not found then raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode='P0002';end if;perform private.assert_catalog_permission_locked(v_identity.library_id,'CATALOG_EDIT',v_actor);if v_replay is not null then return v_replay;end if;if v_identity.row_version is distinct from p_expected_identity_row_version or v_old.row_version is distinct from p_expected_version_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 v_content_hash:=private.canonical_request_hash(jsonb_build_object('name_fr',btrim(p_name_fr),'name_ar',btrim(p_name_ar),'description_fr',btrim(p_description_fr),'description_ar',btrim(p_description_ar),'icon_key',case when p_icon_key is null then null else btrim(p_icon_key) end,'sort_order',p_sort_order,'visibility_rules',p_visibility_rules,'sensitive',p_sensitive));if v_old.status='DRAFT' then update public.catalog_subcategory_versions set name_fr=btrim(p_name_fr),name_ar=btrim(p_name_ar),description_fr=btrim(p_description_fr),description_ar=btrim(p_description_ar),icon_key=case when p_icon_key is null then null else btrim(p_icon_key) end,sort_order=p_sort_order,visibility_rules=p_visibility_rules,sensitive=p_sensitive,change_reason=btrim(p_change_reason),content_hash=v_content_hash,row_version=row_version+1 where id=p_version_id returning id into v_version;else select coalesce(max(version),0)+1 into v_number from public.catalog_subcategory_versions where subcategory_id=p_subcategory_id;insert into public.catalog_subcategory_versions(subcategory_id,library_id,version,status,name_fr,name_ar,description_fr,description_ar,icon_key,sort_order,visibility_rules,change_reason,content_hash,sensitive,created_by) values(p_subcategory_id,v_identity.library_id,v_number,'DRAFT',btrim(p_name_fr),btrim(p_name_ar),btrim(p_description_fr),btrim(p_description_ar),case when p_icon_key is null then null else btrim(p_icon_key) end,p_sort_order,p_visibility_rules,btrim(p_change_reason),v_content_hash,p_sensitive,v_actor) returning id into v_version;end if;update public.catalog_subcategories set current_draft_version_id=v_version,row_version=row_version+1 where id=p_subcategory_id;select steward_organization_id into v_org from public.catalog_libraries where id=v_identity.library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_SUBCATEGORY_DRAFT_SAVED','subcategory_id',p_subcategory_id,'library_id',v_identity.library_id,'version_id',v_version,'identity_row_version',p_expected_identity_row_version+1,'version_row_version',case when v_old.status='DRAFT' then p_expected_version_row_version+1 else 1 end,'content_hash',v_content_hash,'command_id',v_command);insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.subcategory.draft_saved','catalog_subcategory',p_subcategory_id::text,p_correlation_id,jsonb_build_object('source_version_id',p_version_id,'version_id',v_version,'new_version',v_old.status<>'DRAFT','command_id',v_command),v_old.content_hash,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_subcategory',p_subcategory_id::text,'CatalogSubcategoryDraftSavedV1',p_correlation_id,jsonb_build_object('subcategory_id',p_subcategory_id,'version_id',v_version,'new_version',v_old.status<>'DRAFT'),p_idempotency_key,v_command);perform private.finish_catalog_command(v_actor,'catalog.subcategory.save',p_idempotency_key,v_response);return v_response;
end$$;

create function public.submit_catalog_change(
 p_object_type text,p_object_id uuid,p_version_id uuid,p_expected_identity_row_version integer,p_expected_version_row_version integer,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_library uuid;v_org uuid;v_status text;v_sensitive boolean;v_creator uuid;v_identity_version integer;v_version_version integer;v_hash text;v_command uuid;v_replay jsonb;v_request uuid;v_response jsonb;
begin
 if p_object_type is null or p_object_type not in ('LIBRARY','CATEGORY','SUBCATEGORY') or p_object_id is null or p_version_id is null
    or p_expected_identity_row_version is null or p_expected_identity_row_version<1 or p_expected_version_row_version is null or p_expected_version_row_version<1 then raise exception 'INVALID_CATALOG_CHANGE' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-object:'||p_object_type||':'||p_object_id::text,0));
 if p_object_type='LIBRARY' then select i.id,v.status,v.sensitive,v.created_by,i.row_version,v.row_version into v_library,v_status,v_sensitive,v_creator,v_identity_version,v_version_version from public.catalog_libraries i join public.catalog_library_versions v on v.id=p_version_id and v.library_id=i.id where i.id=p_object_id for update of i,v;
 elsif p_object_type='CATEGORY' then select i.library_id,v.status,v.sensitive,v.created_by,i.row_version,v.row_version into v_library,v_status,v_sensitive,v_creator,v_identity_version,v_version_version from public.catalog_categories i join public.catalog_category_versions v on v.id=p_version_id and v.category_id=i.id where i.id=p_object_id for update of i,v;
 else select i.library_id,v.status,v.sensitive,v.created_by,i.row_version,v.row_version into v_library,v_status,v_sensitive,v_creator,v_identity_version,v_version_version from public.catalog_subcategories i join public.catalog_subcategory_versions v on v.id=p_version_id and v.subcategory_id=i.id where i.id=p_object_id for update of i,v;end if;
 if v_library is null then raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode='P0002';end if;perform private.assert_catalog_permission_locked(v_library,'CATALOG_SUBMIT',v_actor);if v_sensitive and auth.jwt()->>'aal' is distinct from 'aal2' then raise exception 'CATALOG_SENSITIVE_MFA_REQUIRED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.change.submit.v1','object_type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'expected_identity',p_expected_identity_row_version,'expected_version',p_expected_version_row_version));select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.change.submit',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 if v_identity_version is distinct from p_expected_identity_row_version or v_version_version is distinct from p_expected_version_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;if v_status is distinct from 'DRAFT' then raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode='55000';end if;
 insert into public.catalog_change_requests(library_id,target_type,target_id,target_version_id,sensitive,requested_by) values(v_library,p_object_type,p_object_id,p_version_id,v_sensitive,v_actor) returning id into v_request;
 if p_object_type='LIBRARY' then update public.catalog_library_versions set status='IN_REVIEW',row_version=row_version+1 where id=p_version_id;update public.catalog_libraries set status='IN_REVIEW',row_version=row_version+1,updated_at=clock_timestamp() where id=p_object_id;
 elsif p_object_type='CATEGORY' then update public.catalog_category_versions set status='IN_REVIEW',row_version=row_version+1 where id=p_version_id;update public.catalog_categories set status='IN_REVIEW',row_version=row_version+1 where id=p_object_id;
 else update public.catalog_subcategory_versions set status='IN_REVIEW',row_version=row_version+1 where id=p_version_id;update public.catalog_subcategories set status='IN_REVIEW',row_version=row_version+1 where id=p_object_id;end if;select steward_organization_id into v_org from public.catalog_libraries where id=v_library;
 v_response:=jsonb_build_object('outcome','CATALOG_CHANGE_SUBMITTED','change_request_id',v_request,'object_type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'identity_row_version',p_expected_identity_row_version+1,'version_row_version',p_expected_version_row_version+1,'sensitive',v_sensitive,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.change.submitted','catalog_change_request',v_request::text,p_correlation_id,jsonb_build_object('object_type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'sensitive',v_sensitive,'command_id',v_command),null,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_change_request',v_request::text,'CatalogChangeSubmittedV1',p_correlation_id,jsonb_build_object('change_request_id',v_request,'object_type',p_object_type,'object_id',p_object_id,'version_id',p_version_id,'sensitive',v_sensitive),p_idempotency_key,v_command);perform private.finish_catalog_command(v_actor,'catalog.change.submit',p_idempotency_key,v_response);return v_response;
end$$;

create function public.decide_catalog_change(
 p_change_request_id uuid,p_decision text,p_reason text,p_expected_row_version integer,p_idempotency_key text,
 p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_change public.catalog_change_requests%rowtype;v_org uuid;v_hash text;v_command uuid;v_replay jsonb;v_status text;v_before_hash text;v_after_hash text;v_response jsonb;
begin
 if p_change_request_id is null or p_decision is null or p_decision not in ('APPROVE','REJECT') or p_expected_row_version is null or p_expected_row_version<1 or length(btrim(coalesce(p_reason,''))) not between 3 and 1000 then raise exception 'INVALID_CATALOG_DECISION' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-change:'||p_change_request_id::text,0));select * into v_change from public.catalog_change_requests where id=p_change_request_id for update;if not found then raise exception 'CATALOG_CHANGE_NOT_FOUND' using errcode='P0002';end if;
 begin perform private.assert_catalog_central_aal2_locked(v_actor);exception when insufficient_privilege then raise exception 'CATALOG_APPROVAL_DENIED' using errcode='42501';end;perform private.assert_catalog_permission_locked(v_change.library_id,'CATALOG_APPROVE',v_actor);if v_change.requested_by=v_actor then raise exception 'CATALOG_SELF_APPROVAL_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.change.decide.v2','change_request_id',p_change_request_id,'decision',p_decision,'reason',btrim(p_reason),'expected',p_expected_row_version));select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.change.decide',p_idempotency_key,v_hash)b;if v_replay is not null then return v_replay;end if;
 if v_change.status is distinct from 'IN_REVIEW' or v_change.row_version is distinct from p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;perform private.assert_catalog_permission_locked(v_change.library_id,'CATALOG_APPROVE',v_actor);v_status:=case when p_decision='APPROVE' then 'APPROVED' else 'DRAFT' end;
 if v_change.target_type='LIBRARY' then select pv.content_hash into v_before_hash from public.catalog_libraries i left join public.catalog_library_versions pv on pv.id=i.current_published_version_id where i.id=v_change.target_id;perform 1 from public.catalog_library_versions where id=v_change.target_version_id and library_id=v_change.library_id and status='IN_REVIEW' for update;update public.catalog_library_versions set status=v_status,row_version=row_version+1 where id=v_change.target_version_id and library_id=v_change.library_id and status='IN_REVIEW' returning content_hash into v_after_hash;update public.catalog_libraries set status=v_status,row_version=row_version+1,updated_at=clock_timestamp() where id=v_change.target_id;
 elsif v_change.target_type='CATEGORY' then select pv.content_hash into v_before_hash from public.catalog_categories i left join public.catalog_category_versions pv on pv.id=i.current_published_version_id where i.id=v_change.target_id;perform 1 from public.catalog_category_versions where id=v_change.target_version_id and category_id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' for update;update public.catalog_category_versions set status=v_status,row_version=row_version+1 where id=v_change.target_version_id and category_id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' returning content_hash into v_after_hash;update public.catalog_categories set status=v_status,row_version=row_version+1 where id=v_change.target_id;
 elsif v_change.target_type='SUBCATEGORY' then select pv.content_hash into v_before_hash from public.catalog_subcategories i left join public.catalog_subcategory_versions pv on pv.id=i.current_published_version_id where i.id=v_change.target_id;perform 1 from public.catalog_subcategory_versions where id=v_change.target_version_id and subcategory_id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' for update;update public.catalog_subcategory_versions set status=v_status,row_version=row_version+1 where id=v_change.target_version_id and subcategory_id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' returning content_hash into v_after_hash;update public.catalog_subcategories set status=v_status,row_version=row_version+1 where id=v_change.target_id;
 elsif v_change.target_type='RELEASE' then
  select r.snapshot_hash into v_before_hash from public.catalog_libraries l left join public.catalog_releases r on r.id=l.current_release_id where l.id=v_change.library_id;perform 1 from public.catalog_releases where id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' for update;
  if p_decision='APPROVE' then update public.catalog_releases set status='APPROVED',approved_by=v_actor,approved_at=clock_timestamp(),row_version=row_version+1 where id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' returning snapshot_hash into v_after_hash;
  else update public.catalog_releases set status='DRAFT',approved_by=null,approved_at=null,row_version=row_version+1 where id=v_change.target_id and library_id=v_change.library_id and status='IN_REVIEW' returning snapshot_hash into v_after_hash;end if;
 else raise exception 'UNSUPPORTED_CATALOG_CHANGE_TARGET' using errcode='0A000';end if;
 if v_after_hash is null then raise exception 'INVALID_CATALOG_VERSION_STATE' using errcode='55000';end if;
 update public.catalog_change_requests set status=case when p_decision='APPROVE' then 'APPROVED' else 'REJECTED' end,reviewed_by=v_actor,reviewed_at=clock_timestamp(),review_comment=btrim(p_reason),row_version=row_version+1 where id=p_change_request_id;
 select steward_organization_id into v_org from public.catalog_libraries where id=v_change.library_id;insert into public.catalog_approvals(change_request_id,library_id,decision,before_hash,after_hash,comment,decided_by,correlation_id) values(p_change_request_id,v_change.library_id,case when p_decision='APPROVE' then 'APPROVED' else 'REJECTED' end,v_before_hash,v_after_hash,btrim(p_reason),v_actor,p_correlation_id);
 v_response:=jsonb_build_object('outcome',case when p_decision='APPROVE' then 'CATALOG_CHANGE_APPROVED' else 'CATALOG_CHANGE_REJECTED' end,'change_request_id',p_change_request_id,'object_type',v_change.target_type,'object_id',v_change.target_id,'version_id',v_change.target_version_id,'change_row_version',p_expected_row_version+1,'target_status',v_status,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER',case when p_decision='APPROVE' then 'catalog.change.approved' else 'catalog.change.rejected' end,'catalog_change_request',p_change_request_id::text,p_correlation_id,jsonb_build_object('object_type',v_change.target_type,'object_id',v_change.target_id,'version_id',v_change.target_version_id,'reason',btrim(p_reason),'command_id',v_command),null,repeat('0',64));insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id) values(v_org,'catalog_change_request',p_change_request_id::text,case when p_decision='APPROVE' then 'CatalogChangeApprovedV1' else 'CatalogChangeRejectedV1' end,p_correlation_id,jsonb_build_object('change_request_id',p_change_request_id,'object_type',v_change.target_type,'object_id',v_change.target_id,'version_id',v_change.target_version_id),p_idempotency_key,v_command);perform private.finish_catalog_command(v_actor,'catalog.change.decide',p_idempotency_key,v_response);return v_response;
end$$;

create or replace function public.decide_catalog_change(p_change_request_id uuid,p_approved boolean,p_comment text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $$begin if p_approved is null then raise exception 'INVALID_CATALOG_DECISION' using errcode='22023';end if;return public.decide_catalog_change(p_change_request_id,case when p_approved then 'APPROVE' else 'REJECT' end,p_comment,p_expected_row_version,p_idempotency_key,p_correlation_id);end$$;

revoke all on function public.create_catalog_library(uuid,text,text,text,text,text,text,text,integer,boolean,text,text,uuid),public.save_catalog_library_draft(uuid,uuid,text,text,text,text,text,integer,boolean,text,integer,integer,text,uuid),public.create_catalog_category(uuid,text,text,text,text,text,text,text,integer,jsonb,boolean,text,text,uuid),public.save_catalog_category_draft(uuid,uuid,text,text,text,text,text,integer,jsonb,boolean,text,integer,integer,text,uuid),public.create_catalog_subcategory(uuid,text,text,text,text,text,text,text,integer,jsonb,boolean,text,text,uuid),public.save_catalog_subcategory_draft(uuid,uuid,text,text,text,text,text,integer,jsonb,boolean,text,integer,integer,text,uuid),public.submit_catalog_change(text,uuid,uuid,integer,integer,text,uuid),public.decide_catalog_change(uuid,text,text,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_catalog_library(uuid,text,text,text,text,text,text,text,integer,boolean,text,text,uuid),public.save_catalog_library_draft(uuid,uuid,text,text,text,text,text,integer,boolean,text,integer,integer,text,uuid),public.create_catalog_category(uuid,text,text,text,text,text,text,text,integer,jsonb,boolean,text,text,uuid),public.save_catalog_category_draft(uuid,uuid,text,text,text,text,text,integer,jsonb,boolean,text,integer,integer,text,uuid),public.create_catalog_subcategory(uuid,text,text,text,text,text,text,text,integer,jsonb,boolean,text,text,uuid),public.save_catalog_subcategory_draft(uuid,uuid,text,text,text,text,text,integer,jsonb,boolean,text,integer,integer,text,uuid),public.submit_catalog_change(text,uuid,uuid,integer,integer,text,uuid),public.decide_catalog_change(uuid,text,text,integer,text,uuid) to authenticated;
revoke all on function public.decide_catalog_change(uuid,boolean,text,integer,text,uuid) from public,anon,service_role;
grant execute on function public.decide_catalog_change(uuid,boolean,text,integer,text,uuid) to authenticated;

notify pgrst,'reload schema';
