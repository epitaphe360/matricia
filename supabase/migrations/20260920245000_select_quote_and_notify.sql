-- Client selects one submitted quote with an explicit reason, then publishes
-- anonymised ranking feedback to every other comparable quote.
-- Does not expose winner identity, contacts or exact competing prices.
-- Rollback: revoke the wrapper and drop the decision table; selected quotes remain.

create table public.quote_selection_decisions (
  rfq_id uuid primary key references public.rfqs(id) on delete restrict,
  selected_quote_id uuid not null references public.quotes(id) on delete restrict,
  selected_quote_version_id uuid not null references public.quote_versions(id) on delete restrict,
  client_organization_id uuid not null references public.organizations(id) on delete restrict,
  comparison_snapshot_id uuid not null references public.quote_comparison_snapshots(id) on delete restrict,
  selection_reason text not null check (length(btrim(selection_reason)) between 3 and 500),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

create function private.prevent_quote_selection_decision_mutation() returns trigger
language plpgsql set search_path=pg_catalog,public,private as $$begin
  raise exception 'QUOTE_SELECTION_DECISION_IMMUTABLE' using errcode='55000';
end$$;

create trigger quote_selection_decisions_immutable
  before update or delete on public.quote_selection_decisions
  for each row execute function private.prevent_quote_selection_decision_mutation();

revoke all on function private.prevent_quote_selection_decision_mutation() from public,anon,authenticated,service_role;

alter table public.quote_selection_decisions enable row level security;
create policy quote_selection_decisions_client_read on public.quote_selection_decisions
  for select to authenticated
  using (private.has_org_role(client_organization_id, array['CLIENT_OWNER','CLIENT_ADMIN','CLIENT_BUYER','CLIENT_VIEWER']));
revoke all on public.quote_selection_decisions from public,anon,authenticated,service_role;
grant select on public.quote_selection_decisions to authenticated;

create function private.anonymised_not_selected_axes(p_snapshot jsonb, p_quote_id uuid) returns jsonb
language plpgsql immutable set search_path=pg_catalog as $$
declare
  v_row jsonb;
  v_min_total bigint;
  v_min_duration integer;
  v_max_deliverables integer;
  v_axes jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_snapshot->'rows') <> 'array' then
    raise exception 'INVALID_COMPARISON_SNAPSHOT' using errcode='22023';
  end if;
  select min((row_data->>'total_minor')::bigint), min((row_data->>'duration_days')::integer), max((row_data->>'deliverables_count')::integer)
    into v_min_total, v_min_duration, v_max_deliverables
  from jsonb_array_elements(p_snapshot->'rows') row_data;
  select row_data into v_row
  from jsonb_array_elements(p_snapshot->'rows') row_data
  where (row_data->>'quote_id')::uuid = p_quote_id
  limit 1;
  if v_row is null then
    raise exception 'QUOTE_NOT_IN_COMPARISON' using errcode='22023';
  end if;
  if (v_row->>'total_minor')::bigint > v_min_total then
    v_axes := v_axes || jsonb_build_array(jsonb_build_object(
      'dimension', 'FINANCE',
      'message_fr', 'Le montant proposé dépasse le plus bas montant comparable du panel.',
      'message_ar', 'المبلغ المقترح أعلى من أدنى مبلغ قابل للمقارنة في القائمة.'
    ));
  end if;
  if (v_row->>'duration_days')::integer > v_min_duration then
    v_axes := v_axes || jsonb_build_array(jsonb_build_object(
      'dimension', 'DELIVERY',
      'message_fr', 'Le délai proposé dépasse le délai le plus court du panel.',
      'message_ar', 'الأجل المقترح أطول من أقصر أجل في القائمة.'
    ));
  end if;
  if (v_row->>'deliverables_count')::integer < v_max_deliverables then
    v_axes := v_axes || jsonb_build_array(jsonb_build_object(
      'dimension', 'QUALITY',
      'message_fr', 'Le nombre de livrables est inférieur au maximum du panel.',
      'message_ar', 'عدد المخرجات أقل من الحد الأعلى في القائمة.'
    ));
  end if;
  if jsonb_array_length(v_axes) = 0 then
    v_axes := jsonb_build_array(jsonb_build_object(
      'dimension', 'RESPONSIVENESS',
      'message_fr', 'D’autres critères du panel ont été jugés plus adaptés à la demande.',
      'message_ar', 'اُعتبرت معايير أخرى في القائمة أكثر ملاءمة للطلب.'
    ));
  end if;
  return v_axes;
end$$;

revoke all on function private.anonymised_not_selected_axes(jsonb, uuid) from public,anon,authenticated,service_role;

create function public.select_quote_and_notify(
  p_quote_id uuid,
  p_expected_version_id uuid,
  p_selection_reason text,
  p_comparison_snapshot_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  quote public.quotes%rowtype;
  snapshot public.quote_comparison_snapshots%rowtype;
  decision public.quote_selection_decisions%rowtype;
  response jsonb;
  other record;
  feedback_key text;
begin
  if auth.uid() is null or length(btrim(coalesce(p_selection_reason, ''))) not between 3 and 500
     or length(coalesce(p_idempotency_key, '')) not between 8 and 200 then
    raise exception 'INVALID_QUOTE_SELECTION' using errcode='22023';
  end if;

  select * into quote from public.quotes where id = p_quote_id;
  if not found then
    raise exception 'QUOTE_NOT_FOUND' using errcode='P0002';
  end if;
  select * into snapshot from public.quote_comparison_snapshots where id = p_comparison_snapshot_id;
  if not found or snapshot.rfq_id <> quote.rfq_id then
    raise exception 'COMPARISON_SCOPE_DENIED' using errcode='42501';
  end if;

  select * into decision from public.quote_selection_decisions where rfq_id = quote.rfq_id;
  if found then
    if decision.selected_quote_id <> p_quote_id or decision.selected_quote_version_id <> p_expected_version_id then
      raise exception 'QUOTE_ALREADY_SELECTED' using errcode='55000';
    end if;
    return jsonb_build_object(
      'outcome', 'QUOTE_SELECTED',
      'quote_id', decision.selected_quote_id,
      'quote_version_id', decision.selected_quote_version_id,
      'rfq_id', decision.rfq_id,
      'replayed', true
    );
  end if;

  response := public.select_quote(p_quote_id, p_expected_version_id, p_idempotency_key, p_correlation_id);

  insert into public.quote_selection_decisions (
    rfq_id, selected_quote_id, selected_quote_version_id, client_organization_id,
    comparison_snapshot_id, selection_reason, created_by
  ) values (
    quote.rfq_id, p_quote_id, p_expected_version_id, snapshot.client_organization_id,
    snapshot.id, btrim(p_selection_reason), auth.uid()
  );

  for other in
    select id from public.quotes
    where rfq_id = quote.rfq_id and status = 'NOT_SELECTED'
  loop
    feedback_key := encode(extensions.digest(convert_to(p_idempotency_key || ':fb:' || other.id::text, 'UTF8'), 'sha256'), 'hex');
    perform public.publish_not_selected_feedback(
      other.id,
      private.anonymised_not_selected_axes(snapshot.comparison, other.id),
      'QUOTE_COMPARE_V1',
      snapshot.id,
      feedback_key,
      p_correlation_id
    );
  end loop;

  insert into public.audit_events (
    organization_id, actor_user_id, actor_type, action, resource_type, resource_id, correlation_id, metadata, event_hash
  ) values (
    snapshot.client_organization_id, auth.uid(), 'USER', 'quote.selection.reason.recorded', 'quote_selection_decision',
    quote.rfq_id::text, p_correlation_id,
    jsonb_build_object('selected_quote_id', p_quote_id, 'comparison_snapshot_id', snapshot.id),
    repeat('0', 64)
  );

  return response || jsonb_build_object('replayed', false);
end$$;

revoke all on function public.select_quote_and_notify(uuid, uuid, text, uuid, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.select_quote_and_notify(uuid, uuid, text, uuid, text, uuid) to authenticated;
