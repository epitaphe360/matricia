begin;

-- Admin supervision projection: read-only overview for platform roles.
create or replace function public.list_admin_supervision_projection(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
stable
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  lim integer := greatest(1, least(coalesce(p_limit, 50), 100));
begin
  if actor is null or not private.has_platform_role(
    array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','FINANCE_MANAGER','DISPUTE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR'],
    actor
  ) then
    raise exception 'ADMIN_SUPERVISION_DENIED' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'as_of', statement_timestamp(),
    'read_only', private.has_platform_role(array['READ_ONLY_AUDITOR'], actor)
      and not private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','FINANCE_MANAGER','DISPUTE_MANAGER','LIBRARY_MANAGER'], actor),
    'organizations', coalesce((
      select jsonb_agg(item order by item->>'display_name')
      from (
        select jsonb_build_object(
          'id', o.id,
          'display_name', o.display_name,
          'legal_name', o.legal_name,
          'status', o.status,
          'created_at', o.created_at,
          'member_count', (select count(*)::int from public.organization_memberships m where m.organization_id = o.id and m.status = 'ACTIVE'),
          'open_requests', (select count(*)::int from public.service_requests r where r.client_organization_id = o.id and r.status not in ('CANCELLED','CLOSED')),
          'open_disputes', (select count(*)::int from public.dispute_cases d where d.client_organization_id = o.id and d.status <> 'CLOSED')
        ) item
        from public.organizations o
        where o.status in ('ACTIVE','PENDING','SUSPENDED')
        order by o.updated_at desc nulls last, o.created_at desc
        limit lim
      ) q
    ), '[]'::jsonb),
    'requests', coalesce((
      select jsonb_agg(item order by (item->>'created_at') desc)
      from (
        select jsonb_build_object(
          'id', r.id,
          'organization_id', r.client_organization_id,
          'organization_name', o.display_name,
          'status', r.status,
          'library_id', r.library_id,
          'service_id', r.service_id,
          'created_at', r.created_at,
          'matching_runs', (select count(*)::int from public.matching_runs mr where mr.request_id = r.id),
          'rfq_count', (select count(*)::int from public.rfqs q where q.request_id = r.id),
          'quote_count', (select count(*)::int from public.quotes qt join public.rfqs q on q.id = qt.rfq_id where q.request_id = r.id)
        ) item
        from public.service_requests r
        join public.organizations o on o.id = r.client_organization_id
        order by r.created_at desc
        limit lim
      ) q
    ), '[]'::jsonb),
    'quotes', coalesce((
      select jsonb_agg(item order by (item->>'updated_at') desc)
      from (
        select jsonb_build_object(
          'id', qt.id,
          'rfq_id', qt.rfq_id,
          'request_id', q.request_id,
          'provider_organization_id', qt.provider_organization_id,
          'provider_name', po.display_name,
          'client_name', co.display_name,
          'status', qt.status,
          'updated_at', qt.updated_at
        ) item
        from public.quotes qt
        join public.rfqs q on q.id = qt.rfq_id
        join public.service_requests r on r.id = q.request_id
        join public.organizations co on co.id = r.client_organization_id
        join public.organizations po on po.id = qt.provider_organization_id
        order by qt.updated_at desc nulls last
        limit lim
      ) q
    ), '[]'::jsonb),
    'missions', coalesce((
      select jsonb_agg(item order by (item->>'updated_at') desc)
      from (
        select jsonb_build_object(
          'id', m.id,
          'contract_id', m.contract_id,
          'status', m.status,
          'client_organization_id', m.client_organization_id,
          'provider_organization_id', m.provider_organization_id,
          'client_name', co.display_name,
          'provider_name', po.display_name,
          'updated_at', m.updated_at,
          'milestone_count', (select count(*)::int from public.mission_milestones mm where mm.mission_id = m.id),
          'deliverable_count', (select count(*)::int from public.deliverables md where md.mission_id = m.id)
        ) item
        from public.missions m
        join public.organizations co on co.id = m.client_organization_id
        join public.organizations po on po.id = m.provider_organization_id
        order by m.updated_at desc nulls last
        limit lim
      ) q
    ), '[]'::jsonb),
    'diagnostics', coalesce((
      select jsonb_agg(item order by (item->>'completed_at') desc)
      from (
        select jsonb_build_object(
          'id', d.id,
          'organization_id', d.organization_id,
          'organization_name', o.display_name,
          'status', d.status,
          'rating', d.rating,
          'overall_score', d.overall_score,
          'completed_at', d.completed_at
        ) item
        from public.diagnostic_runs d
        join public.organizations o on o.id = d.organization_id
        order by d.completed_at desc nulls last
        limit lim
      ) q
    ), '[]'::jsonb),
    'work_enrichment', coalesce((
      select jsonb_object_agg(x.id::text, x.payload)
      from (
        select w.id, jsonb_build_object(
          'organization_name', o.display_name,
          'assignee_label', coalesce(p.display_name, case when w.assigned_to is null then null else left(w.assigned_to::text, 8) end)
        ) payload
        from public.admin_work_items w
        left join public.organizations o on o.id = w.organization_id
        left join public.user_profiles p on p.id = w.assigned_to
        where w.status in ('OPEN','CLAIMED','WAITING_INFORMATION')
        order by w.severity_rank desc, w.due_at
        limit 200
      ) x
    ), '{}'::jsonb)
  );
end;
$$;

revoke all on function public.list_admin_supervision_projection(integer) from public, anon;
grant execute on function public.list_admin_supervision_projection(integer) to authenticated;

create or replace function public.get_admin_organization_fiche(p_organization_id uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = pg_catalog, public, private
as $$
declare
  actor uuid := auth.uid();
  org public.organizations%rowtype;
begin
  if actor is null or not private.has_platform_role(
    array['SUPER_ADMIN','MATRICIA_ADMIN','COMPLIANCE_MANAGER','FINANCE_MANAGER','DISPUTE_MANAGER','LIBRARY_MANAGER','READ_ONLY_AUDITOR'],
    actor
  ) then
    raise exception 'ADMIN_ORG_FICHE_DENIED' using errcode = '42501';
  end if;
  if p_organization_id is null then
    raise exception 'INVALID_ORGANIZATION' using errcode = '22023';
  end if;
  select * into org from public.organizations where id = p_organization_id;
  if not found then
    raise exception 'ORGANIZATION_NOT_FOUND' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'organization', jsonb_build_object(
      'id', org.id,
      'display_name', org.display_name,
      'legal_name', org.legal_name,
      'status', org.status,
      'country_code', org.country_code,
      'created_at', org.created_at,
      'updated_at', org.updated_at
    ),
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id,
        'user_id', m.user_id,
        'status', m.status,
        'roles', coalesce((
          select jsonb_agg(r.role_code order by r.role_code)
          from public.organization_member_roles r
          where r.membership_id = m.id and r.revoked_at is null
        ), '[]'::jsonb)
      ) order by m.activated_at desc nulls last)
      from public.organization_memberships m
      where m.organization_id = org.id
      limit 100
    ), '[]'::jsonb),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'status', r.status, 'created_at', r.created_at, 'service_id', r.service_id
      ) order by r.created_at desc)
      from public.service_requests r
      where r.client_organization_id = org.id
      limit 50
    ), '[]'::jsonb),
    'missions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.id, 'status', m.status, 'updated_at', m.updated_at,
        'as_client', m.client_organization_id = org.id,
        'as_provider', m.provider_organization_id = org.id
      ) order by m.updated_at desc nulls last)
      from public.missions m
      where m.client_organization_id = org.id or m.provider_organization_id = org.id
      limit 50
    ), '[]'::jsonb),
    'disputes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'status', d.status, 'urgency', d.urgency, 'mission_id', d.mission_id, 'response_due_at', d.response_due_at
      ) order by d.opened_at desc)
      from public.dispute_cases d
      where d.client_organization_id = org.id or d.provider_organization_id = org.id
      limit 50
    ), '[]'::jsonb),
    'diagnostics', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'status', d.status, 'rating', d.rating, 'overall_score', d.overall_score, 'completed_at', d.completed_at
      ) order by d.completed_at desc nulls last)
      from public.diagnostic_runs d
      where d.organization_id = org.id
      limit 30
    ), '[]'::jsonb),
    'subscriptions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'status', s.status, 'plan_version_id', s.plan_version_id, 'current_period_end', s.current_period_end
      ) order by s.updated_at desc nulls last)
      from public.subscriptions s
      where s.organization_id = org.id
      limit 20
    ), '[]'::jsonb),
    'timeline', coalesce((
      select jsonb_agg(event order by (event->>'at') desc)
      from (
        select jsonb_build_object('at', r.created_at, 'kind', 'REQUEST', 'label', 'Demande '||r.status, 'ref', r.id::text) event
        from public.service_requests r where r.client_organization_id = org.id
        union all
        select jsonb_build_object('at', m.updated_at, 'kind', 'MISSION', 'label', 'Mission '||m.status, 'ref', m.id::text) event
        from public.missions m where m.client_organization_id = org.id or m.provider_organization_id = org.id
        union all
        select jsonb_build_object('at', d.opened_at, 'kind', 'DISPUTE', 'label', 'Litige '||d.status, 'ref', d.id::text) event
        from public.dispute_cases d where d.client_organization_id = org.id or d.provider_organization_id = org.id
        order by 1 desc
        limit 40
      ) t
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.get_admin_organization_fiche(uuid) from public, anon;
grant execute on function public.get_admin_organization_fiche(uuid) to authenticated;

commit;
