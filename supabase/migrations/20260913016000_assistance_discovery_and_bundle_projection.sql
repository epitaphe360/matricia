-- MAT-FUNC-008/010: bounded text discovery and exact, tenant-filtered bundle projection.
-- The question corpus remains bounded to the selected service candidates.

create or replace function public.discover_assistance_scope(
  p_organization_id uuid,
  p_input_text text,
  p_known_data_keys text[] default '{}',
  p_limit integer default 20
) returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_actor uuid := auth.uid();
  v_services jsonb;
  v_questions jsonb;
begin
  if not private.assistance_role_access(p_organization_id, 'ANALYSE', v_actor) then
    raise exception 'ASSISTANCE_ACCESS_DENIED' using errcode = '42501';
  end if;
  if length(btrim(coalesce(p_input_text, ''))) not between 3 and 1000 or p_limit not between 1 and 20
     or cardinality(coalesce(p_known_data_keys, '{}')) > 100 then
    raise exception 'INVALID_ASSISTANCE_DISCOVERY' using errcode = '22023';
  end if;

  with ranked as (
    select version.id,
           service.id as service_id,
           private.assistance_overlap_basis_points(
             p_input_text,
             concat_ws(' ', version.name_fr, version.short_description_fr, version.name_ar, version.short_description_ar, version.code)
           ) as score_basis_points
    from public.catalog_service_versions version
    join public.catalog_services service on service.id = version.service_id
    where version.status = 'PUBLISHED'
      and service.status = 'PUBLISHED'
      and service.current_published_version_id = version.id
    order by score_basis_points desc, version.id
    limit p_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'service_version_id', id,
    'service_id', service_id,
    'score_basis_points', score_basis_points
  ) order by score_basis_points desc, id), '[]'::jsonb)
  into v_services
  from ranked
  where score_basis_points > 0;

  with selected_services as (
    select (item->>'service_id')::uuid as service_id
    from jsonb_array_elements(v_services) item
  ), ranked_questions as (
    select question.id,
           question.source_service_id,
           question.required_for_quote,
           private.assistance_overlap_basis_points(
             p_input_text,
             concat_ws(' ', question.label_fr, question.help_fr, question.label_ar, question.help_ar, question.data_key)
           ) as score_basis_points
    from public.question_versions question
    join selected_services selected on selected.service_id = question.source_service_id
    where question.status = 'PUBLISHED'
      and not (question.data_key = any(coalesce(p_known_data_keys, '{}')))
      and not exists (
        select 1
        from public.questionnaire_sessions session
        join public.questionnaire_answers answer on answer.session_id = session.id and answer.question_version_id = question.id
        join public.questionnaire_answer_revisions revision on revision.id = answer.current_revision_id
        where session.organization_id = p_organization_id
          and revision.value <> 'null'::jsonb
          and (revision.expires_at is null or revision.expires_at > statement_timestamp())
      )
    order by question.required_for_quote desc, score_basis_points desc, question.id
    limit 50
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'question_version_id', id,
    'service_id', source_service_id,
    'required_for_quote', required_for_quote,
    'score_basis_points', score_basis_points
  ) order by required_for_quote desc, score_basis_points desc, id), '[]'::jsonb)
  into v_questions
  from ranked_questions;

  return jsonb_build_object(
    'outcome', 'ASSISTANCE_SCOPE_DISCOVERED',
    'algorithm', 'TOKEN_OVERLAP_V1',
    'service_candidates', v_services,
    'question_candidates', v_questions,
    'human_confirmation_required', true
  );
end
$$;

create or replace function public.list_solution_bundles_v1()
returns jsonb
language sql stable security invoker
set search_path = pg_catalog, public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', bundle.id,
    'organization_id', bundle.organization_id,
    'bundle_key', bundle.bundle_key,
    'version', bundle.version,
    'title_fr', bundle.title_fr,
    'title_ar', bundle.title_ar,
    'description_fr', bundle.description_fr,
    'description_ar', bundle.description_ar,
    'source_manifest_hash', bundle.source_manifest_hash,
    'fusion_policy_snapshot', bundle.fusion_policy_snapshot,
    'library_codes', bundle.library_codes,
    'total_amount_minor', bundle.total_amount_minor::text,
    'currency', bundle.currency,
    'created_at', bundle.created_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id,
        'service_id', item.service_id,
        'service_version_id', item.service_version_id,
        'library_id', item.library_id,
        'dedupe_key', item.dedupe_key,
        'fusion_strategy', item.fusion_strategy,
        'source_count', item.source_count,
        'provenance', item.provenance,
        'amount_minor', item.amount_minor::text,
        'sort_order', item.sort_order
      ) order by item.sort_order)
      from public.solution_bundle_items item
      where item.bundle_version_id = bundle.id
    ), '[]'::jsonb)
  ) order by bundle.created_at desc, bundle.id), '[]'::jsonb)
  from (select * from public.solution_bundle_versions order by created_at desc, id limit 100) bundle
$$;

create index if not exists question_versions_published_service_discovery_idx
on public.question_versions(source_service_id, id) where status = 'PUBLISHED' and source_service_id is not null;

revoke all on function public.discover_assistance_scope(uuid,text,text[],integer), public.list_solution_bundles_v1()
from public, anon, authenticated, service_role;
grant execute on function public.discover_assistance_scope(uuid,text,text[],integer), public.list_solution_bundles_v1()
to authenticated;

comment on function public.discover_assistance_scope(uuid,text,text[],integer) is
  'Bounded deterministic discovery. Returns candidates only; human confirmation remains mandatory.';
comment on function public.list_solution_bundles_v1() is
  'RLS-filtered bundle versions with exact bigint TEXT amounts and immutable provenance.';
