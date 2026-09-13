-- Restore organization-level mission milestones while enriching linked ones with project_id.
create or replace function public.client_central_calendar_items()
returns table(
  organization_id uuid,project_id uuid,item_id uuid,source_kind text,event_type text,
  title_fr text,title_ar text,starts_at timestamptz,ends_at timestamptz,status text,
  occurs_on date,all_day boolean
) language sql stable security definer set search_path=pg_catalog,public,private as $$
  select e.organization_id,e.project_id,e.id,'CLIENT_EVENT',e.event_type,e.title_fr,e.title_ar,
    e.starts_at,e.ends_at,e.status,null::date,false
  from public.client_calendar_events e where private.client_portfolio_read(e.organization_id)
  union all
  select t.organization_id,t.project_id,t.id,'PROJECT_TASK',t.task_type,v.title_fr,v.title_ar,
    t.due_at,null::timestamptz,t.status,null::date,false
  from public.client_project_tasks t join public.client_project_task_versions v on v.task_id=t.id and v.version=t.current_version
  where t.due_at is not null and private.client_portfolio_read(t.organization_id)
  union all
  select m.client_organization_id,pc.project_id,ms.id,'MISSION_MILESTONE','MISSION',ms.title_fr,ms.title_ar,
    ms.due_at,null::timestamptz,ms.status,null::date,false
  from public.missions m join public.mission_milestones ms on ms.mission_id=m.id
  left join public.client_project_contracts pc on pc.contract_id=m.contract_id and pc.organization_id=m.client_organization_id
  where ms.due_at is not null and private.client_portfolio_read(m.client_organization_id)
  union all
  select sr.client_organization_id,null::uuid,r.id,'RFQ_DEADLINE','QUOTE',
    'Date limite de remise des devis','الموعد النهائي لتقديم عروض الأسعار',r.deadline,null::timestamptz,r.status,null::date,false
  from public.rfqs r join public.service_requests sr on sr.id=r.request_id
  where r.status='OPEN' and private.client_portfolio_read(sr.client_organization_id)
  union all
  select sr.client_organization_id,null::uuid,qv.id,'QUOTE_VALIDITY','QUOTE',
    'Expiration du devis','انتهاء صلاحية عرض السعر',qv.valid_until,null::timestamptz,qv.lifecycle_status,null::date,false
  from public.quote_versions qv join public.quotes q on q.id=qv.quote_id
  join public.rfqs r on r.id=q.rfq_id join public.service_requests sr on sr.id=r.request_id
  where q.current_version_id=qv.id and q.status not in('WITHDRAWN','EXPIRED')
    and private.client_portfolio_read(sr.client_organization_id)
  union all
  select i.organization_id,i.project_id,i.id,'INVOICE_DUE','INVOICE',
    'Échéance de facture','موعد استحقاق الفاتورة',
    i.due_on::timestamp at time zone 'Africa/Casablanca',null::timestamptz,i.status,i.due_on,true
  from public.client_invoice_calendar_items i where private.client_portfolio_read(i.organization_id)
  union all
  select d.organization_id,null::uuid,d.id,'DOCUMENT_EXPIRY','DOCUMENT',
    'Expiration document '||d.document_type,'انتهاء صلاحية المستند '||d.document_type,
    d.expires_on::timestamp at time zone 'Africa/Casablanca',null::timestamptz,d.status,d.expires_on,true
  from public.client_compliance_documents d
  where d.expires_on is not null and d.status not in('REJECTED','QUARANTINED','SUPERSEDED')
    and private.client_portfolio_read(d.organization_id)
$$;

revoke all on function public.client_central_calendar_items() from public,anon,service_role;
grant execute on function public.client_central_calendar_items() to authenticated;
