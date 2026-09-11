-- P06 client catalogue reads: immutable snapshot identity, fail-closed visibility and keyset pagination.

do $$
begin
  if exists(select 1 from public.catalog_library_versions group by library_id having count(*)>1)
    or exists(select 1 from public.catalog_category_versions group by category_id having count(*)>1)
    or exists(select 1 from public.catalog_subcategory_versions group by subcategory_id having count(*)>1)
    or exists(select 1 from public.catalog_service_versions group by service_id having count(*)>1)
    or exists(select 1 from public.catalog_service_subcategory_link_versions group by link_id having count(*)>1)
    or exists(select 1 from public.catalog_release_items i join public.catalog_libraries x on i.object_type='LIBRARY' and x.id=i.object_id where i.version_id is distinct from coalesce(x.current_published_version_id,x.current_draft_version_id))
    or exists(select 1 from public.catalog_release_items i join public.catalog_categories x on i.object_type='CATEGORY' and x.id=i.object_id where i.version_id is distinct from coalesce(x.current_published_version_id,x.current_draft_version_id))
    or exists(select 1 from public.catalog_release_items i join public.catalog_subcategories x on i.object_type='SUBCATEGORY' and x.id=i.object_id where i.version_id is distinct from coalesce(x.current_published_version_id,x.current_draft_version_id))
    or exists(select 1 from public.catalog_release_items i join public.catalog_services x on i.object_type='SERVICE' and x.id=i.object_id where i.version_id is distinct from coalesce(x.current_published_version_id,x.current_draft_version_id))
    or exists(select 1 from public.catalog_release_items i join public.catalog_service_subcategory_links x on i.object_type='SERVICE_SUBCATEGORY_LINK' and x.id=i.object_id where i.version_id is distinct from x.current_version_id) then
    raise exception 'CATALOG_VERSION_IDENTITY_BACKFILL_AMBIGUOUS' using errcode='55000';
  end if;
end;
$$;

alter table public.catalog_library_versions add column code text, add column slug text;
alter table public.catalog_category_versions add column code text, add column slug text;
alter table public.catalog_subcategory_versions add column category_id uuid, add column code text, add column slug text;
alter table public.catalog_service_versions add column primary_subcategory_id uuid, add column code text, add column slug text;
alter table public.catalog_service_subcategory_link_versions add column service_id uuid, add column subcategory_id uuid, add column link_type text;

alter table public.catalog_library_versions disable trigger catalog_library_versions_immutable;
alter table public.catalog_category_versions disable trigger catalog_category_versions_immutable;
alter table public.catalog_subcategory_versions disable trigger catalog_subcategory_versions_immutable;
alter table public.catalog_service_versions disable trigger catalog_service_versions_immutable;
alter table public.catalog_service_subcategory_link_versions disable trigger catalog_link_versions_immutable;
update public.catalog_library_versions v set code=x.code,slug=x.slug from public.catalog_libraries x where x.id=v.library_id;
update public.catalog_category_versions v set code=x.code,slug=x.slug from public.catalog_categories x where x.id=v.category_id and x.library_id=v.library_id;
update public.catalog_subcategory_versions v set category_id=x.category_id,code=x.code,slug=x.slug from public.catalog_subcategories x where x.id=v.subcategory_id and x.library_id=v.library_id;
update public.catalog_service_versions v set primary_subcategory_id=x.primary_subcategory_id,code=x.code,slug=x.slug from public.catalog_services x where x.id=v.service_id and x.library_id=v.library_id;
update public.catalog_service_subcategory_link_versions v set service_id=x.service_id,subcategory_id=x.subcategory_id,link_type=x.link_type from public.catalog_service_subcategory_links x where x.id=v.link_id and x.library_id=v.library_id;
alter table public.catalog_library_versions enable trigger catalog_library_versions_immutable;
alter table public.catalog_category_versions enable trigger catalog_category_versions_immutable;
alter table public.catalog_subcategory_versions enable trigger catalog_subcategory_versions_immutable;
alter table public.catalog_service_versions enable trigger catalog_service_versions_immutable;
alter table public.catalog_service_subcategory_link_versions enable trigger catalog_link_versions_immutable;

alter table public.catalog_library_versions alter column code set not null,alter column slug set not null,
 add constraint catalog_library_versions_code_check check(code~'^[A-Z][A-Z0-9_-]{1,31}$'),add constraint catalog_library_versions_slug_check check(slug~'^[a-z0-9]+(?:-[a-z0-9]+)*$');
alter table public.catalog_category_versions alter column code set not null,alter column slug set not null,
 add constraint catalog_category_versions_code_check check(code~'^[A-Z][A-Z0-9_-]{1,79}$'),add constraint catalog_category_versions_slug_check check(slug~'^[a-z0-9]+(?:-[a-z0-9]+)*$');
alter table public.catalog_subcategory_versions alter column category_id set not null,alter column code set not null,alter column slug set not null,
 add constraint catalog_subcategory_versions_parent_fk foreign key(category_id,library_id) references public.catalog_categories(id,library_id) on delete restrict,
 add constraint catalog_subcategory_versions_code_check check(code~'^[A-Z][A-Z0-9_-]{1,79}$'),add constraint catalog_subcategory_versions_slug_check check(slug~'^[a-z0-9]+(?:-[a-z0-9]+)*$');
alter table public.catalog_service_versions alter column primary_subcategory_id set not null,alter column code set not null,alter column slug set not null,
 add constraint catalog_service_versions_parent_fk foreign key(primary_subcategory_id,library_id) references public.catalog_subcategories(id,library_id) on delete restrict,
 add constraint catalog_service_versions_code_check check(code~'^[A-Z][A-Z0-9_-]{1,79}$'),add constraint catalog_service_versions_slug_check check(slug~'^[a-z0-9]+(?:-[a-z0-9]+)*$');
alter table public.catalog_service_subcategory_link_versions alter column service_id set not null,alter column subcategory_id set not null,alter column link_type set not null,
 add constraint catalog_link_versions_service_fk foreign key(service_id,library_id) references public.catalog_services(id,library_id) on delete restrict,
 add constraint catalog_link_versions_subcategory_fk foreign key(subcategory_id,library_id) references public.catalog_subcategories(id,library_id) on delete restrict,
 add constraint catalog_link_versions_type_check check(link_type in ('PRIMARY','SECONDARY'));

create function private.catalog_client_visibility_allows(p_rules jsonb) returns boolean
language sql immutable security definer set search_path=pg_catalog,private
as $$select p_rules='{}'::jsonb$$;
revoke all on function private.catalog_client_visibility_allows(jsonb) from public,anon,authenticated,service_role;

create function private.visible_catalog_snapshot_services(p_release_id uuid,p_locale text)
returns table(
 release_id uuid,library_id uuid,library_code text,library_slug text,library_name text,library_description text,library_icon_key text,library_sort_order integer,
 service_id uuid,service_code text,service_slug text,service_name text,short_description text,long_description text,service_type text,unit_label text,
 credit_eligible boolean,volume_eligible boolean,recurring_eligible boolean,trial_eligible boolean,rfq_required boolean,service_sort_order integer,
 category_id uuid,category_slug text,category_name text,subcategory_id uuid,subcategory_slug text,subcategory_name text
)
language sql stable security definer set search_path=pg_catalog,private
as $$
 select r.id,r.library_id,lv.code,lv.slug,case p_locale when 'ar' then lv.name_ar else lv.name_fr end,case p_locale when 'ar' then lv.description_ar else lv.description_fr end,lv.icon_key,lv.sort_order,
  sv.service_id,sv.code,sv.slug,case p_locale when 'ar' then sv.name_ar else sv.name_fr end,case p_locale when 'ar' then sv.short_description_ar else sv.short_description_fr end,case p_locale when 'ar' then sv.long_description_ar else sv.long_description_fr end,sv.service_type,case p_locale when 'ar' then sv.unit_label_ar else sv.unit_label_fr end,
  sv.credit_eligible,sv.volume_eligible,sv.recurring_eligible,sv.trial_eligible,sv.rfq_required,sv.sort_order,
  cv.category_id,cv.slug,case p_locale when 'ar' then cv.name_ar else cv.name_fr end,scv.subcategory_id,scv.slug,case p_locale when 'ar' then scv.name_ar else scv.name_fr end
 from public.catalog_releases r
 join public.catalog_release_items li on li.release_id=r.id and li.library_id=r.library_id and li.object_type='LIBRARY' and li.object_id=r.library_id
 join public.catalog_library_versions lv on lv.id=li.version_id and lv.library_id=li.library_id
 join public.catalog_release_items si on si.release_id=r.id and si.library_id=r.library_id and si.object_type='SERVICE'
 join public.catalog_service_versions sv on sv.id=si.version_id and sv.service_id=si.object_id and sv.library_id=si.library_id
 join public.catalog_release_items xi on xi.release_id=r.id and xi.library_id=r.library_id and xi.object_type='SERVICE_SUBCATEGORY_LINK'
 join public.catalog_service_subcategory_link_versions xv on xv.id=xi.version_id and xv.link_id=xi.object_id and xv.library_id=xi.library_id and xv.service_id=sv.service_id and xv.link_type='PRIMARY' and xv.subcategory_id=sv.primary_subcategory_id
 join public.catalog_release_items sci on sci.release_id=r.id and sci.library_id=r.library_id and sci.object_type='SUBCATEGORY' and sci.object_id=xv.subcategory_id
 join public.catalog_subcategory_versions scv on scv.id=sci.version_id and scv.subcategory_id=sci.object_id and scv.library_id=sci.library_id
 join public.catalog_release_items ci on ci.release_id=r.id and ci.library_id=r.library_id and ci.object_type='CATEGORY' and ci.object_id=scv.category_id
 join public.catalog_category_versions cv on cv.id=ci.version_id and cv.category_id=ci.object_id and cv.library_id=ci.library_id
 where r.id=p_release_id and r.status='PUBLISHED' and statement_timestamp()>=r.effective_from and (r.effective_until is null or statement_timestamp()<r.effective_until)
  and p_locale in ('fr','ar') and private.can_read_catalog_release(r.id,auth.uid())
  and private.catalog_client_visibility_allows(sv.visibility_rules) and private.catalog_client_visibility_allows(scv.visibility_rules) and private.catalog_client_visibility_allows(cv.visibility_rules)
$$;
revoke all on function private.visible_catalog_snapshot_services(uuid,text) from public,anon,authenticated,service_role;

create function public.list_client_catalog_libraries(p_locale text) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog,private
as $$
declare v_actor uuid:=auth.uid();v_result jsonb;
begin
 if v_actor is null or auth.role() is distinct from 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
 if p_locale is null or p_locale not in ('fr','ar') then raise exception 'INVALID_CATALOG_LOCALE' using errcode='22023'; end if;
 select jsonb_build_object('locale',p_locale,'items',coalesce(jsonb_agg(x.payload order by x.sort_order,x.code collate "C",x.release_id),'[]'::jsonb)) into v_result
 from(select r.id release_id,lv.sort_order,lv.code,jsonb_build_object('release_id',r.id,'library',jsonb_build_object('id',r.library_id,'code',lv.code,'slug',lv.slug,'name',case p_locale when 'ar' then lv.name_ar else lv.name_fr end,'description',case p_locale when 'ar' then lv.description_ar else lv.description_fr end,'icon_key',lv.icon_key,'sort_order',lv.sort_order),'category_count',coalesce(c.category_count,0),'service_count',coalesce(c.service_count,0)) payload
  from public.catalog_releases r join public.catalog_release_items li on li.release_id=r.id and li.library_id=r.library_id and li.object_type='LIBRARY' and li.object_id=r.library_id join public.catalog_library_versions lv on lv.id=li.version_id and lv.library_id=li.library_id
  left join lateral(select count(distinct s.category_id) category_count,count(*) service_count from private.visible_catalog_snapshot_services(r.id,p_locale)s)c on true
  where r.status='PUBLISHED' and statement_timestamp()>=r.effective_from and (r.effective_until is null or statement_timestamp()<r.effective_until) and private.can_read_catalog_release(r.id,v_actor) and coalesce(c.service_count,0)>0
  order by lv.sort_order,lv.code collate "C",r.id limit 10)x;
 return v_result;
end;
$$;

create function public.search_client_catalog_release(p_release_id uuid,p_locale text,p_search text,p_cursor jsonb,p_page_size integer) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog,private
as $$
declare v_actor uuid:=auth.uid();v_search text;v_sort integer;v_name text;v_code text;v_id uuid;v_valid boolean;v_result jsonb;
begin
 if v_actor is null or auth.role() is distinct from 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
 if p_locale is null or p_locale not in ('fr','ar') then raise exception 'INVALID_CATALOG_LOCALE' using errcode='22023'; end if;
 if p_release_id is null then raise exception 'INVALID_CATALOG_RELEASE_ID' using errcode='22023'; end if;
 if p_search is not null and char_length(p_search)>80 then raise exception 'CATALOG_SEARCH_TOO_LONG' using errcode='22023'; end if;
 if p_page_size is null or p_page_size<1 or p_page_size>12 then raise exception 'INVALID_CATALOG_PAGE_SIZE' using errcode='22023'; end if;
 if p_cursor is not null and (jsonb_typeof(p_cursor)<>'object' or (select count(*) from jsonb_object_keys(p_cursor))<>4 or not(p_cursor?&array['sort_order','name','code','service_id']) or jsonb_typeof(p_cursor->'sort_order')<>'number' or (p_cursor->>'sort_order')!~'^[0-9]{1,10}$' or (p_cursor->>'sort_order')::numeric not between 1 and 2147483647 or jsonb_typeof(p_cursor->'name')<>'string' or char_length(p_cursor->>'name') not between 1 and 240 or jsonb_typeof(p_cursor->'code')<>'string' or (p_cursor->>'code')!~'^[A-Z][A-Z0-9_-]{1,79}$' or jsonb_typeof(p_cursor->'service_id')<>'string' or (p_cursor->>'service_id')!~'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') then raise exception 'INVALID_CATALOG_CURSOR' using errcode='22023'; end if;
 v_search:=lower(btrim(coalesce(p_search,'')));if p_cursor is not null then v_sort:=(p_cursor->>'sort_order')::integer;v_name:=p_cursor->>'name';v_code:=p_cursor->>'code';v_id:=(p_cursor->>'service_id')::uuid;end if;
 if not private.can_read_catalog_release(p_release_id,v_actor) then return null;end if;
 with library_context as(select r.library_id,lv.code,lv.slug,case p_locale when 'ar' then lv.name_ar else lv.name_fr end name,case p_locale when 'ar' then lv.description_ar else lv.description_fr end description,lv.icon_key,lv.sort_order from public.catalog_releases r join public.catalog_release_items i on i.release_id=r.id and i.library_id=r.library_id and i.object_type='LIBRARY' and i.object_id=r.library_id join public.catalog_library_versions lv on lv.id=i.version_id and lv.library_id=i.library_id where r.id=p_release_id),visible as materialized(select * from private.visible_catalog_snapshot_services(p_release_id,p_locale)),filtered as materialized(select * from visible where v_search='' or position(v_search in lower(concat_ws(' ',service_code,service_slug,service_name,short_description,category_name,subcategory_name)))>0),cursor_check as(select p_cursor is null or exists(select 1 from filtered where service_id=v_id and service_sort_order=v_sort and service_name=v_name and service_code=v_code) valid),page_rows as(select f.*,row_number()over(order by service_sort_order,service_name collate "C",service_code collate "C",service_id) rn from filtered f,cursor_check c where c.valid and(p_cursor is null or(service_sort_order,service_name collate "C",service_code collate "C",service_id)>(v_sort,v_name collate "C",v_code collate "C",v_id)) order by service_sort_order,service_name collate "C",service_code collate "C",service_id limit p_page_size+1)
 select c.valid,jsonb_build_object('release_id',p_release_id,'locale',p_locale,'page_size',p_page_size,'total',(select count(*)from filtered),'category_count',(select count(distinct category_id)from visible),'service_count',(select count(*)from visible),'library',(select jsonb_build_object('id',library_id,'code',code,'slug',slug,'name',name,'description',description,'icon_key',icon_key,'sort_order',sort_order)from library_context),'services',coalesce((select jsonb_agg(jsonb_build_object('service',jsonb_build_object('id',service_id,'code',service_code,'slug',service_slug,'name',service_name,'short_description',short_description,'long_description',long_description,'service_type',service_type,'unit_label',unit_label,'credit_eligible',credit_eligible,'volume_eligible',volume_eligible,'recurring_eligible',recurring_eligible,'trial_eligible',trial_eligible,'rfq_required',rfq_required,'sort_order',service_sort_order),'category',jsonb_build_object('id',category_id,'slug',category_slug,'name',category_name),'subcategory',jsonb_build_object('id',subcategory_id,'slug',subcategory_slug,'name',subcategory_name))order by rn)from page_rows where rn<=p_page_size),'[]'::jsonb),'has_more',(select count(*)>p_page_size from page_rows),'next_cursor',case when(select count(*)>p_page_size from page_rows)then(select jsonb_build_object('sort_order',service_sort_order,'name',service_name,'code',service_code,'service_id',service_id)from page_rows where rn=p_page_size)else null end) into v_valid,v_result from cursor_check c;
 if p_cursor is not null and not coalesce(v_valid,false)then raise exception 'INVALID_CATALOG_CURSOR' using errcode='22023';end if;return v_result;
end;
$$;

create function public.get_client_catalog_service(p_release_id uuid,p_locale text,p_service_slug text) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog,private
as $$
declare v_actor uuid:=auth.uid();v_result jsonb;
begin
 if v_actor is null or auth.role() is distinct from 'authenticated' then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';end if;
 if p_locale is null or p_locale not in('fr','ar')then raise exception 'INVALID_CATALOG_LOCALE' using errcode='22023';end if;
 if p_release_id is null then raise exception 'INVALID_CATALOG_RELEASE_ID' using errcode='22023';end if;
 if p_service_slug is null or char_length(p_service_slug)not between 1 and 200 or p_service_slug!~'^[a-z0-9]+(?:-[a-z0-9]+)*$'then raise exception 'INVALID_CATALOG_SERVICE_SLUG' using errcode='22023';end if;
 if not private.can_read_catalog_release(p_release_id,v_actor)then return null;end if;
 with visible as materialized(select * from private.visible_catalog_snapshot_services(p_release_id,p_locale)),counts as(select count(distinct category_id)category_count,count(*)service_count from visible)
 select jsonb_build_object('release_id',p_release_id,'locale',p_locale,'category_count',c.category_count,'service_count',c.service_count,'library',jsonb_build_object('id',s.library_id,'code',s.library_code,'slug',s.library_slug,'name',s.library_name,'description',s.library_description,'icon_key',s.library_icon_key,'sort_order',s.library_sort_order),'service',jsonb_build_object('id',s.service_id,'code',s.service_code,'slug',s.service_slug,'name',s.service_name,'short_description',s.short_description,'long_description',s.long_description,'service_type',s.service_type,'unit_label',s.unit_label,'credit_eligible',s.credit_eligible,'volume_eligible',s.volume_eligible,'recurring_eligible',s.recurring_eligible,'trial_eligible',s.trial_eligible,'rfq_required',s.rfq_required,'sort_order',s.service_sort_order),'category',jsonb_build_object('id',s.category_id,'slug',s.category_slug,'name',s.category_name),'subcategory',jsonb_build_object('id',s.subcategory_id,'slug',s.subcategory_slug,'name',s.subcategory_name))into v_result from visible s cross join counts c where s.service_slug=p_service_slug;
 return v_result;
end;
$$;

revoke all on function public.list_client_catalog_libraries(text),public.search_client_catalog_release(uuid,text,text,jsonb,integer),public.get_client_catalog_service(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.list_client_catalog_libraries(text),public.search_client_catalog_release(uuid,text,text,jsonb,integer),public.get_client_catalog_service(uuid,text,text) to authenticated;
