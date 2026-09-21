begin;

-- Read-only enrichment of the admin supervision projection for parcours 24–56.
-- Additive keys only. No mutation verbs. Same platform-role gate as 20260916120000.

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
    'matching', coalesce((
      select jsonb_agg(item order by (item->>'started_at') desc)
      from (
        select jsonb_build_object(
          'id', mr.id,
          'request_id', mr.request_id,
          'organization_id', r.client_organization_id,
          'organization_name', o.display_name,
          'status', mr.status,
          'policy_version', mr.policy_version,
          'started_at', mr.started_at,
          'eligible_count', (select count(*)::int from public.matching_candidates c where c.matching_run_id = mr.id and c.eligible),
          'excluded_count', (select count(*)::int from public.matching_candidates c where c.matching_run_id = mr.id and not c.eligible),
          'rfq_count', (select count(*)::int from public.rfqs q where q.matching_run_id = mr.id),
          'candidates', coalesce((
            select jsonb_agg(jsonb_build_object(
              'provider_organization_id', c.provider_organization_id,
              'provider_name', po.display_name,
              'eligible', c.eligible,
              'score_basis_points', c.score_basis_points,
              'exclusion_reasons', to_jsonb(c.exclusion_reasons)
            ) order by c.eligible desc, c.score_basis_points desc)
            from public.matching_candidates c
            join public.organizations po on po.id = c.provider_organization_id
            where c.matching_run_id = mr.id
            limit 20
          ), '[]'::jsonb)
        ) item
        from public.matching_runs mr
        join public.service_requests r on r.id = mr.request_id
        join public.organizations o on o.id = r.client_organization_id
        order by mr.started_at desc
        limit lim
      ) q
    ), '[]'::jsonb),
    'contracts', coalesce((
      select jsonb_agg(item order by (item->>'id'))
      from (
        select jsonb_build_object(
          'id', c.id,
          'status', c.status,
          'current_version', c.current_version,
          'client_organization_id', c.client_organization_id,
          'provider_organization_id', c.provider_organization_id,
          'client_name', co.display_name,
          'provider_name', po.display_name,
          'signature_count', (select count(*)::int from public.contract_signatures s where s.contract_id = c.id),
          'mission_id', (select m.id from public.missions m where m.contract_id = c.id order by m.created_at desc limit 1)
        ) item
        from public.contracts c
        join public.organizations co on co.id = c.client_organization_id
        join public.organizations po on po.id = c.provider_organization_id
        order by c.created_at desc
        limit lim
      ) q
    ), '[]'::jsonb),
    'amendments', coalesce((
      select jsonb_agg(item order by (item->>'amendment_number') desc)
      from (
        select jsonb_build_object(
          'id', a.id,
          'contract_id', a.contract_id,
          'status', a.status,
          'amendment_number', a.amendment_number,
          'price_delta_minor', a.price_delta_minor::text,
          'client_name', co.display_name,
          'provider_name', po.display_name,
          'client_organization_id', c.client_organization_id
        ) item
        from public.contract_amendments a
        join public.contracts c on c.id = a.contract_id
        join public.organizations co on co.id = c.client_organization_id
        join public.organizations po on po.id = c.provider_organization_id
        order by a.created_at desc
        limit lim
      ) q
    ), '[]'::jsonb),
    'documents', coalesce((
      select jsonb_agg(item)
      from (
        (
          select jsonb_build_object(
            'id', d.id,
            'kind', 'CLIENT_COMPLIANCE',
            'code', d.document_type,
            'status', d.status,
            'organization_id', d.organization_id,
            'organization_name', o.display_name,
            'expires_on', d.expires_on,
            'version', d.version
          ) item
          from public.client_compliance_documents d
          join public.organizations o on o.id = d.organization_id
          order by d.created_at desc
          limit 40
        )
        union all
        (
          select jsonb_build_object(
            'id', v.id,
            'kind', f.document_kind,
            'code', f.code,
            'status', v.status,
            'organization_id', f.provider_organization_id,
            'organization_name', o.display_name,
            'expires_on', v.expires_on,
            'version', v.version_number
          ) item
          from public.provider_document_versions v
          join public.provider_document_families f on f.id = v.family_id
          join public.organizations o on o.id = f.provider_organization_id
          order by v.created_at desc
          limit 40
        )
      ) q
    ), '[]'::jsonb),
    'messages', coalesce((
      select jsonb_agg(item order by (item->>'created_at') desc)
      from (
        select jsonb_build_object(
          'id', t.id,
          'subject', t.subject,
          'status', t.status,
          'object_id', t.object_id,
          'service_request_id', t.service_request_id,
          'client_organization_id', t.client_organization_id,
          'provider_organization_id', t.provider_organization_id,
          'client_name', co.display_name,
          'provider_name', po.display_name,
          'created_at', t.created_at
        ) item
        from public.internal_message_threads t
        join public.organizations co on co.id = t.client_organization_id
        join public.organizations po on po.id = t.provider_organization_id
        order by t.created_at desc
        limit lim
      ) q
    ), '[]'::jsonb),
    'exceptions', coalesce((
      select jsonb_agg(item order by (item->>'due_at'))
      from (
        select jsonb_build_object(
          'id', w.id,
          'source_kind', w.source_kind,
          'priority', w.priority,
          'status', w.status,
          'due_at', w.due_at,
          'title_fr', w.title_fr,
          'title_ar', w.title_ar,
          'resource_type', w.resource_type,
          'resource_id', w.resource_id,
          'organization_id', w.organization_id
        ) item
        from public.admin_work_items w
        where w.status in ('OPEN','CLAIMED','WAITING_INFORMATION')
          and w.source_kind in ('EXCEPTION','SLA_BREACH','FINANCE','DISPUTE','DOCUMENT','POOL')
        order by w.severity_rank desc, w.due_at
        limit lim
      ) q
    ), '[]'::jsonb),
    'templates', coalesce((
      select jsonb_agg(item order by item->>'template_code')
      from (
        select jsonb_build_object(
          'id', t.id,
          'template_code', t.template_code,
          'event_type', t.event_type,
          'category_code', t.category_code,
          'locale', t.locale,
          'version', t.version,
          'status', t.status,
          'mandatory', t.mandatory,
          'channels', to_jsonb(t.channels)
        ) item
        from public.notification_template_versions t
        where t.status = 'ACTIVE'
        order by t.template_code, t.locale
        limit 80
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

commit;
