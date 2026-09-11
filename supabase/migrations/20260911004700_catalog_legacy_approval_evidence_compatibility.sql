-- Preserve release-approval evidence consumed by pre-hierarchy clients while
-- retaining the richer hierarchy decision audit introduced in migration 043.

create function private.prepare_catalog_approval_compatibility()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare v_target_type text;
begin
 select target_type into v_target_type
 from public.catalog_change_requests where id=new.change_request_id;
 if v_target_type='RELEASE' then
  new.before_hash:=coalesce(new.before_hash,repeat('0',64));
  new.after_hash:=coalesce(new.after_hash,repeat('0',64));
 end if;
 return new;
end$$;

create function private.audit_catalog_approval_compatibility()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
declare v_org uuid;
begin
 select l.steward_organization_id into v_org
 from public.catalog_change_requests c
 join public.catalog_libraries l on l.id=c.library_id
 where c.id=new.change_request_id;
 insert into public.audit_events(
  organization_id,actor_user_id,actor_type,action,resource_type,resource_id,
  correlation_id,metadata,previous_hash,event_hash
 ) values(
  v_org,new.decided_by,'USER','catalog.change.decided','catalog_change_request',
  new.change_request_id::text,new.correlation_id,
  jsonb_build_object('decision',new.decision,'compatibility_contract','v1'),
  null,repeat('0',64)
 );
 return new;
end$$;

create trigger catalog_approval_10_prepare_compatibility
before insert on public.catalog_approvals for each row
execute function private.prepare_catalog_approval_compatibility();

create trigger catalog_approval_90_audit_compatibility
after insert on public.catalog_approvals for each row
execute function private.audit_catalog_approval_compatibility();

revoke all on function
 private.prepare_catalog_approval_compatibility(),
 private.audit_catalog_approval_compatibility()
from public,anon,authenticated,service_role;

