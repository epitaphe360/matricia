-- Additive compatibility for writers created before catalogue snapshot identity columns existed.

create function private.complete_catalog_library_version_identity() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_code text;v_slug text;
begin
  select x.code,x.slug into v_code,v_slug from public.catalog_libraries x where x.id=new.library_id;
  if not found then raise exception 'CATALOG_LIBRARY_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  if new.code is not null and new.code is distinct from v_code or new.slug is not null and new.slug is distinct from v_slug then raise exception 'CATALOG_LIBRARY_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  new.code:=coalesce(new.code,v_code);new.slug:=coalesce(new.slug,v_slug);
  return new;
end $$;

create function private.complete_catalog_category_version_identity() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_code text;v_slug text;
begin
  select x.code,x.slug into v_code,v_slug from public.catalog_categories x where x.id=new.category_id and x.library_id=new.library_id;
  if not found then raise exception 'CATALOG_CATEGORY_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  if new.code is not null and new.code is distinct from v_code or new.slug is not null and new.slug is distinct from v_slug then raise exception 'CATALOG_CATEGORY_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  new.code:=coalesce(new.code,v_code);new.slug:=coalesce(new.slug,v_slug);
  return new;
end $$;

create function private.complete_catalog_subcategory_version_identity() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_category_id uuid;v_code text;v_slug text;
begin
  select x.category_id,x.code,x.slug into v_category_id,v_code,v_slug from public.catalog_subcategories x where x.id=new.subcategory_id and x.library_id=new.library_id;
  if not found then raise exception 'CATALOG_SUBCATEGORY_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  if new.category_id is not null and new.category_id is distinct from v_category_id or new.code is not null and new.code is distinct from v_code or new.slug is not null and new.slug is distinct from v_slug then raise exception 'CATALOG_SUBCATEGORY_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  new.category_id:=coalesce(new.category_id,v_category_id);new.code:=coalesce(new.code,v_code);new.slug:=coalesce(new.slug,v_slug);
  return new;
end $$;

create function private.complete_catalog_service_version_identity() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_parent_id uuid;v_code text;v_slug text;
begin
  select x.primary_subcategory_id,x.code,x.slug into v_parent_id,v_code,v_slug from public.catalog_services x where x.id=new.service_id and x.library_id=new.library_id;
  if not found then raise exception 'CATALOG_SERVICE_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  if new.primary_subcategory_id is not null and new.primary_subcategory_id is distinct from v_parent_id or new.code is not null and new.code is distinct from v_code or new.slug is not null and new.slug is distinct from v_slug then raise exception 'CATALOG_SERVICE_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  new.primary_subcategory_id:=coalesce(new.primary_subcategory_id,v_parent_id);new.code:=coalesce(new.code,v_code);new.slug:=coalesce(new.slug,v_slug);
  return new;
end $$;

create function private.complete_catalog_link_version_identity() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare v_service_id uuid;v_subcategory_id uuid;v_link_type text;
begin
  select x.service_id,x.subcategory_id,x.link_type into v_service_id,v_subcategory_id,v_link_type from public.catalog_service_subcategory_links x where x.id=new.link_id and x.library_id=new.library_id;
  if not found then raise exception 'CATALOG_LINK_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  if new.service_id is not null and new.service_id is distinct from v_service_id or new.subcategory_id is not null and new.subcategory_id is distinct from v_subcategory_id or new.link_type is not null and new.link_type is distinct from v_link_type then raise exception 'CATALOG_LINK_VERSION_IDENTITY_MISMATCH' using errcode='23514';end if;
  new.service_id:=coalesce(new.service_id,v_service_id);new.subcategory_id:=coalesce(new.subcategory_id,v_subcategory_id);new.link_type:=coalesce(new.link_type,v_link_type);
  return new;
end $$;

revoke all on function private.complete_catalog_library_version_identity(),private.complete_catalog_category_version_identity(),private.complete_catalog_subcategory_version_identity(),private.complete_catalog_service_version_identity(),private.complete_catalog_link_version_identity() from public,anon,authenticated,service_role;

create trigger catalog_library_versions_complete_identity before insert on public.catalog_library_versions for each row execute function private.complete_catalog_library_version_identity();
create trigger catalog_category_versions_complete_identity before insert on public.catalog_category_versions for each row execute function private.complete_catalog_category_version_identity();
create trigger catalog_subcategory_versions_complete_identity before insert on public.catalog_subcategory_versions for each row execute function private.complete_catalog_subcategory_version_identity();
create trigger catalog_service_versions_complete_identity before insert on public.catalog_service_versions for each row execute function private.complete_catalog_service_version_identity();
create trigger catalog_link_versions_complete_identity before insert on public.catalog_service_subcategory_link_versions for each row execute function private.complete_catalog_link_version_identity();
