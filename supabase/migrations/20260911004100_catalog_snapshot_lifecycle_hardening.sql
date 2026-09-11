-- Freeze approved and released catalogue snapshots without blocking controlled lifecycle transitions.

create table private.catalog_version_write_capabilities(
  backend_pid integer not null,transaction_id bigint not null,version_id uuid not null,operation text not null check(operation in ('LIFECYCLE','ATTEST')),
  old_status text not null,new_status text not null,published_at timestamptz,retired_at timestamptz,reviewer_id uuid,reviewed_at timestamptz,proof_hash text,translation_version integer,
  primary key(backend_pid,transaction_id,version_id,operation)
);
revoke all on table private.catalog_version_write_capabilities from public,anon,authenticated,service_role;

create function private.authorize_catalog_version_lifecycle(p_version_id uuid,p_old_status text,p_new_status text,p_published_at timestamptz,p_retired_at timestamptz) returns void
language sql volatile security definer set search_path=pg_catalog as $$ insert into private.catalog_version_write_capabilities(backend_pid,transaction_id,version_id,operation,old_status,new_status,published_at,retired_at) values(pg_backend_pid(),txid_current(),p_version_id,'LIFECYCLE',p_old_status,p_new_status,p_published_at,p_retired_at) $$;
create function private.authorize_catalog_version_attestation(p_version_id uuid,p_status text,p_reviewer_id uuid,p_reviewed_at timestamptz,p_proof_hash text,p_translation_version integer) returns void
language sql volatile security definer set search_path=pg_catalog as $$ insert into private.catalog_version_write_capabilities(backend_pid,transaction_id,version_id,operation,old_status,new_status,reviewer_id,reviewed_at,proof_hash,translation_version) values(pg_backend_pid(),txid_current(),p_version_id,'ATTEST',p_status,p_status,p_reviewer_id,p_reviewed_at,p_proof_hash,p_translation_version) $$;
revoke all on function private.authorize_catalog_version_lifecycle(uuid,text,text,timestamptz,timestamptz),private.authorize_catalog_version_attestation(uuid,text,uuid,timestamptz,text,integer) from public,anon,authenticated,service_role;

create function private.enforce_catalog_version_snapshot_lifecycle() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_object_type text;v_locked boolean;v_old jsonb:=to_jsonb(old);v_new jsonb;v_authorized integer;
begin
  v_object_type:=case tg_table_name when 'catalog_library_versions' then 'LIBRARY' when 'catalog_category_versions' then 'CATEGORY' when 'catalog_subcategory_versions' then 'SUBCATEGORY' when 'catalog_service_versions' then 'SERVICE' when 'catalog_service_subcategory_link_versions' then 'SERVICE_SUBCATEGORY_LINK' else null end;
  if v_object_type is null then raise exception 'CATALOG_VERSION_GUARD_TABLE_INVALID' using errcode='55000';end if;
  v_locked:=old.status in ('APPROVED','PUBLISHED','RETIRED','ARCHIVED') or exists(select 1 from public.catalog_release_items i join public.catalog_releases r on r.id=i.release_id where i.object_type=v_object_type and i.version_id=old.id and r.status<>'DRAFT');
  if tg_op='DELETE' then if v_locked then raise exception 'IMMUTABLE_CATALOG_SNAPSHOT' using errcode='55000';end if;return old;end if;
  if not v_locked or to_jsonb(new)=v_old then return new;end if;v_new:=to_jsonb(new);
  if (v_new-array['status','published_at','retired_at','row_version'])=(v_old-array['status','published_at','retired_at','row_version']) and new.row_version=old.row_version+1 and (
    (old.status='APPROVED' and new.status='PUBLISHED' and new.published_at is not null and new.retired_at is null)
    or (old.status='PUBLISHED' and new.status='PUBLISHED' and new.published_at is not distinct from old.published_at and new.retired_at is null)
    or (old.status='PUBLISHED' and new.status='RETIRED' and new.published_at is not distinct from old.published_at and new.retired_at is not null)
    or (old.status='RETIRED' and new.status='PUBLISHED' and new.published_at is not null and new.retired_at is null)
  ) then
    delete from private.catalog_version_write_capabilities c where c.backend_pid=pg_backend_pid() and c.transaction_id=txid_current() and c.version_id=old.id and c.operation='LIFECYCLE' and c.old_status=old.status and c.new_status=new.status and c.published_at is not distinct from new.published_at and c.retired_at is not distinct from new.retired_at;
    get diagnostics v_authorized=row_count;if v_authorized=1 then return new;end if;
  end if;
  if v_old?'translation_review_status' and old.status=new.status and new.row_version=old.row_version+1
     and (v_new-array['translation_review_status','translation_reviewer_user_id','translation_reviewed_at','translation_review_proof_hash','translation_review_version','row_version'])=(v_old-array['translation_review_status','translation_reviewer_user_id','translation_reviewed_at','translation_review_proof_hash','translation_review_version','row_version'])
     and v_old->>'translation_review_status'<>'APPROVED' and v_new->>'translation_review_status'='APPROVED'
     and v_new->'translation_reviewer_user_id'<>'null'::jsonb and v_new->'translation_reviewed_at'<>'null'::jsonb
     and coalesce(v_new->>'translation_review_proof_hash','')~'^[0-9a-f]{64}$'
     and (v_new->>'translation_review_version')::integer=(v_old->>'translation_review_version')::integer+1 then
    delete from private.catalog_version_write_capabilities c where c.backend_pid=pg_backend_pid() and c.transaction_id=txid_current() and c.version_id=old.id and c.operation='ATTEST' and c.old_status=old.status and c.new_status=new.status and c.reviewer_id=(v_new->>'translation_reviewer_user_id')::uuid and c.reviewed_at=(v_new->>'translation_reviewed_at')::timestamptz and c.proof_hash=v_new->>'translation_review_proof_hash' and c.translation_version=(v_new->>'translation_review_version')::integer;
    get diagnostics v_authorized=row_count;if v_authorized=1 then return new;end if;
  end if;
  raise exception 'IMMUTABLE_CATALOG_SNAPSHOT' using errcode='55000';
end $$;
revoke all on function private.enforce_catalog_version_snapshot_lifecycle() from public,anon,authenticated,service_role;

create trigger catalog_library_snapshot_lifecycle_guard before update or delete on public.catalog_library_versions for each row execute function private.enforce_catalog_version_snapshot_lifecycle();
create trigger catalog_category_snapshot_lifecycle_guard before update or delete on public.catalog_category_versions for each row execute function private.enforce_catalog_version_snapshot_lifecycle();
create trigger catalog_subcategory_snapshot_lifecycle_guard before update or delete on public.catalog_subcategory_versions for each row execute function private.enforce_catalog_version_snapshot_lifecycle();
create trigger catalog_service_snapshot_lifecycle_guard before update or delete on public.catalog_service_versions for each row execute function private.enforce_catalog_version_snapshot_lifecycle();
create trigger catalog_link_snapshot_lifecycle_guard before update or delete on public.catalog_service_subcategory_link_versions for each row execute function private.enforce_catalog_version_snapshot_lifecycle();

create or replace function private.activate_catalog_release_items(p_release_id uuid) returns void
language plpgsql security definer set search_path=pg_catalog as $$
declare v_item public.catalog_release_items%rowtype;v_id uuid;v_status text;v_published_at timestamptz;v_now timestamptz;
begin
 for v_item in select * from public.catalog_release_items where release_id=p_release_id order by sort_order,object_type,object_id loop v_now:=clock_timestamp();
  if v_item.object_type='LIBRARY' then
   for v_id,v_published_at in select id,published_at from public.catalog_library_versions where library_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id loop perform private.authorize_catalog_version_lifecycle(v_id,'PUBLISHED','RETIRED',v_published_at,v_now);update public.catalog_library_versions set status='RETIRED',retired_at=v_now,row_version=row_version+1 where id=v_id;end loop;
   select status,published_at into v_status,v_published_at from public.catalog_library_versions where id=v_item.version_id;v_published_at:=coalesce(v_published_at,v_now);perform private.authorize_catalog_version_lifecycle(v_item.version_id,v_status,'PUBLISHED',v_published_at,null);update public.catalog_library_versions set status='PUBLISHED',published_at=v_published_at,retired_at=null,row_version=row_version+1 where id=v_item.version_id;
   update public.catalog_libraries set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1,updated_at=v_now where id=v_item.object_id;
  elsif v_item.object_type='CATEGORY' then
   for v_id,v_published_at in select id,published_at from public.catalog_category_versions where category_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id loop perform private.authorize_catalog_version_lifecycle(v_id,'PUBLISHED','RETIRED',v_published_at,v_now);update public.catalog_category_versions set status='RETIRED',retired_at=v_now,row_version=row_version+1 where id=v_id;end loop;
   select status,published_at into v_status,v_published_at from public.catalog_category_versions where id=v_item.version_id;v_published_at:=coalesce(v_published_at,v_now);perform private.authorize_catalog_version_lifecycle(v_item.version_id,v_status,'PUBLISHED',v_published_at,null);update public.catalog_category_versions set status='PUBLISHED',published_at=v_published_at,retired_at=null,row_version=row_version+1 where id=v_item.version_id;update public.catalog_categories set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  elsif v_item.object_type='SUBCATEGORY' then
   for v_id,v_published_at in select id,published_at from public.catalog_subcategory_versions where subcategory_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id loop perform private.authorize_catalog_version_lifecycle(v_id,'PUBLISHED','RETIRED',v_published_at,v_now);update public.catalog_subcategory_versions set status='RETIRED',retired_at=v_now,row_version=row_version+1 where id=v_id;end loop;
   select status,published_at into v_status,v_published_at from public.catalog_subcategory_versions where id=v_item.version_id;v_published_at:=coalesce(v_published_at,v_now);perform private.authorize_catalog_version_lifecycle(v_item.version_id,v_status,'PUBLISHED',v_published_at,null);update public.catalog_subcategory_versions set status='PUBLISHED',published_at=v_published_at,retired_at=null,row_version=row_version+1 where id=v_item.version_id;update public.catalog_subcategories set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  elsif v_item.object_type='SERVICE' then
   for v_id,v_published_at in select id,published_at from public.catalog_service_versions where service_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id loop perform private.authorize_catalog_version_lifecycle(v_id,'PUBLISHED','RETIRED',v_published_at,v_now);update public.catalog_service_versions set status='RETIRED',retired_at=v_now,row_version=row_version+1 where id=v_id;end loop;
   select status,published_at into v_status,v_published_at from public.catalog_service_versions where id=v_item.version_id;v_published_at:=coalesce(v_published_at,v_now);perform private.authorize_catalog_version_lifecycle(v_item.version_id,v_status,'PUBLISHED',v_published_at,null);update public.catalog_service_versions set status='PUBLISHED',published_at=v_published_at,retired_at=null,row_version=row_version+1 where id=v_item.version_id;update public.catalog_services set status='PUBLISHED',current_published_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  elsif v_item.object_type='SERVICE_SUBCATEGORY_LINK' then
   for v_id,v_published_at in select id,published_at from public.catalog_service_subcategory_link_versions where link_id=v_item.object_id and status='PUBLISHED' and id<>v_item.version_id loop perform private.authorize_catalog_version_lifecycle(v_id,'PUBLISHED','RETIRED',v_published_at,v_now);update public.catalog_service_subcategory_link_versions set status='RETIRED',retired_at=v_now,row_version=row_version+1 where id=v_id;end loop;
   select status,published_at into v_status,v_published_at from public.catalog_service_subcategory_link_versions where id=v_item.version_id;v_published_at:=coalesce(v_published_at,v_now);perform private.authorize_catalog_version_lifecycle(v_item.version_id,v_status,'PUBLISHED',v_published_at,null);update public.catalog_service_subcategory_link_versions set status='PUBLISHED',published_at=v_published_at,retired_at=null,row_version=row_version+1 where id=v_item.version_id;update public.catalog_service_subcategory_links set status='PUBLISHED',current_version_id=v_item.version_id,row_version=row_version+1 where id=v_item.object_id;
  else raise exception 'INVALID_CATALOG_OBJECT_TYPE' using errcode='22023';end if;
 end loop;
end $$;
revoke all on function private.activate_catalog_release_items(uuid) from public,anon,authenticated,service_role;

create function private.enforce_catalog_release_item_lifecycle() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_status text;v_target uuid;
begin
  perform 1 from public.catalog_releases r where r.id in (case when tg_op in ('UPDATE','DELETE') then old.release_id else new.release_id end,case when tg_op in ('INSERT','UPDATE') then new.release_id else old.release_id end) order by r.id for update;
  if tg_op in ('UPDATE','DELETE') then select status into v_status from public.catalog_releases where id=old.release_id;if v_status is distinct from 'DRAFT' then raise exception 'IMMUTABLE_CATALOG_RELEASE_ITEMS' using errcode='55000';end if;end if;
  if tg_op='UPDATE' then select status into v_status from public.catalog_releases where id=new.release_id;if v_status is distinct from 'DRAFT' then raise exception 'IMMUTABLE_CATALOG_RELEASE_ITEMS' using errcode='55000';end if;end if;
  if tg_op='INSERT' then
    select status,rollback_target_release_id into v_status,v_target from public.catalog_releases where id=new.release_id;
    if v_status is distinct from 'DRAFT' and not (v_status='SCHEDULED' and v_target is not null and exists(select 1 from public.catalog_release_items i where i.release_id=v_target and i.library_id=new.library_id and i.object_type=new.object_type and i.object_id=new.object_id and i.version_id=new.version_id and i.content_hash=new.content_hash and i.sort_order=new.sort_order)) then raise exception 'IMMUTABLE_CATALOG_RELEASE_ITEMS' using errcode='55000';end if;
  end if;
  return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function private.enforce_catalog_release_item_lifecycle() from public,anon,authenticated,service_role;
create trigger catalog_release_items_00_lifecycle_guard before insert or update or delete on public.catalog_release_items for each row execute function private.enforce_catalog_release_item_lifecycle();

create or replace function public.attest_catalog_ar_translation(p_object_type text,p_version_id uuid,p_proof_hash text,p_expected_row_version integer,p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb
language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_library_id uuid;v_status text;v_row_version integer;v_created_by uuid;v_translation_version integer;v_hash text;v_existing public.catalog_command_keys%rowtype;v_response jsonb;v_org uuid;v_now timestamptz;
begin
 if p_object_type not in ('LIBRARY','CATEGORY','SUBCATEGORY','SERVICE') or coalesce(p_proof_hash,'')!~'^[0-9a-f]{64}$' then raise exception 'INVALID_TRANSLATION_ATTESTATION' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('catalog-translation:'||p_version_id::text,0));
 select library_id,status,row_version,created_by,translation_review_version into v_library_id,v_status,v_row_version,v_created_by,v_translation_version from(
  select library_id,status,row_version,created_by,translation_review_version from public.catalog_library_versions where p_object_type='LIBRARY' and id=p_version_id union all
  select library_id,status,row_version,created_by,translation_review_version from public.catalog_category_versions where p_object_type='CATEGORY' and id=p_version_id union all
  select library_id,status,row_version,created_by,translation_review_version from public.catalog_subcategory_versions where p_object_type='SUBCATEGORY' and id=p_version_id union all
  select library_id,status,row_version,created_by,translation_review_version from public.catalog_service_versions where p_object_type='SERVICE' and id=p_version_id)v;
 if v_library_id is null then raise exception 'CATALOG_VERSION_NOT_FOUND' using errcode='P0002';end if;
 if v_actor is null or auth.jwt()->>'aal' is distinct from 'aal2' or v_created_by=v_actor or not private.has_library_permission(v_library_id,'CATALOG_APPROVE',v_actor) then raise exception 'TRANSLATION_REVIEW_DENIED' using errcode='42501';end if;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.translation.attest.v1','object_type',p_object_type,'version_id',p_version_id,'proof_hash',p_proof_hash,'expected',p_expected_row_version));
 select * into v_existing from public.catalog_command_keys where actor_user_id=v_actor and operation_scope='catalog.translation.attest' and key=p_idempotency_key;if found then if v_existing.request_hash<>v_hash then raise exception 'IDEMPOTENCY_PAYLOAD_MISMATCH' using errcode='22000';end if;return v_existing.response_body;end if;
 if v_row_version<>p_expected_row_version then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;if v_status in ('PUBLISHED','RETIRED','ARCHIVED') then raise exception 'IMMUTABLE_CATALOG_HISTORY' using errcode='55000';end if;
 insert into public.catalog_command_keys values(v_actor,'catalog.translation.attest',p_idempotency_key,v_hash,null,clock_timestamp(),null);
 v_now:=clock_timestamp();
 perform private.authorize_catalog_version_attestation(p_version_id,v_status,v_actor,v_now,p_proof_hash,v_translation_version+1);
 if p_object_type='LIBRARY' then update public.catalog_library_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=v_now,translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;
 elsif p_object_type='CATEGORY' then update public.catalog_category_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=v_now,translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;
 elsif p_object_type='SUBCATEGORY' then update public.catalog_subcategory_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=v_now,translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;
 else update public.catalog_service_versions set translation_review_status='APPROVED',translation_reviewer_user_id=v_actor,translation_reviewed_at=v_now,translation_review_proof_hash=p_proof_hash,translation_review_version=translation_review_version+1,row_version=row_version+1 where id=p_version_id and row_version=p_expected_row_version;end if;
 if not found then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;select steward_organization_id into v_org from public.catalog_libraries where id=v_library_id;
 v_response:=jsonb_build_object('outcome','CATALOG_AR_TRANSLATION_ATTESTED','object_type',p_object_type,'version_id',p_version_id,'translation_review_version',v_translation_version+1,'row_version',p_expected_row_version+1);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash) values(v_org,v_actor,'USER','catalog.translation.attested','catalog_translation',p_version_id::text,p_correlation_id,jsonb_build_object('object_type',p_object_type,'proof_hash',p_proof_hash,'translation_review_version',v_translation_version+1),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload) values(v_org,'catalog_translation',p_version_id::text,'CatalogArabicTranslationAttestedV1',p_correlation_id,jsonb_build_object('object_type',p_object_type,'version_id',p_version_id,'translation_review_version',v_translation_version+1));
 update public.catalog_command_keys set response_body=v_response,completed_at=clock_timestamp() where actor_user_id=v_actor and operation_scope='catalog.translation.attest' and key=p_idempotency_key;return v_response;
end $$;
revoke all on function public.attest_catalog_ar_translation(text,uuid,text,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.attest_catalog_ar_translation(text,uuid,text,integer,text,uuid) to authenticated;
