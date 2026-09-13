-- MAT-FUNC-011/021: project contracts and authoritative central-calendar projections.

alter table public.contracts
  add constraint contracts_id_client_organization_unique unique(id,client_organization_id);

create table public.client_project_contracts(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  project_id uuid not null,
  contract_id uuid not null,
  idempotency_key text not null check(length(idempotency_key) between 8 and 200),
  correlation_id uuid not null,
  linked_by uuid not null references auth.users(id) on delete restrict,
  linked_at timestamptz not null default clock_timestamp(),
  unique(contract_id),
  unique(project_id,contract_id),
  unique(organization_id,id),
  foreign key(project_id,organization_id) references public.client_projects(id,organization_id) on delete restrict,
  foreign key(contract_id,organization_id) references public.contracts(id,client_organization_id) on delete restrict
);

create trigger client_project_contracts_immutable
before update or delete on public.client_project_contracts
for each row execute function private.prevent_update_delete();

alter table public.client_project_contracts enable row level security;
create policy client_project_contracts_read on public.client_project_contracts
for select to authenticated using(private.client_portfolio_read(organization_id));
revoke all on public.client_project_contracts from public,anon,authenticated;
grant select on public.client_project_contracts to authenticated;

create table public.client_invoice_calendar_items(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  project_id uuid not null,
  source_invoice_id uuid not null references public.provider_invoices(id) on delete restrict,
  due_on date not null,
  status text not null default 'DUE' check(status in('DUE')),
  created_at timestamptz not null default clock_timestamp(),
  unique(project_id,source_invoice_id),
  unique(id,organization_id),
  foreign key(project_id,organization_id) references public.client_projects(id,organization_id) on delete restrict
);
create trigger client_invoice_calendar_items_immutable before update or delete on public.client_invoice_calendar_items
for each row execute function private.prevent_update_delete();
alter table public.client_invoice_calendar_items enable row level security;
create policy client_invoice_calendar_items_read on public.client_invoice_calendar_items
for select to authenticated using(private.client_portfolio_read(organization_id));
revoke all on public.client_invoice_calendar_items from public,anon,authenticated;
grant select(id,organization_id,project_id,due_on,status) on public.client_invoice_calendar_items to authenticated;

create function private.project_client_invoice_deadline() returns trigger language plpgsql security definer
set search_path=pg_catalog,public,private,extensions as $$
begin
  if tg_table_name='provider_invoices' then
    insert into public.client_invoice_calendar_items(organization_id,project_id,source_invoice_id,due_on)
    select distinct pc.organization_id,pc.project_id,new.id,new.due_on
    from public.provider_statement_lines sl join public.provider_payable_events pe on pe.id=sl.payable_event_id
    join public.missions m on m.id=pe.mission_id join public.client_project_contracts pc on pc.contract_id=m.contract_id
    where sl.statement_id=new.statement_id on conflict do nothing;
  else
    insert into public.client_invoice_calendar_items(organization_id,project_id,source_invoice_id,due_on)
    select distinct new.organization_id,new.project_id,i.id,i.due_on
    from public.missions m join public.provider_payable_events pe on pe.mission_id=m.id
    join public.provider_statement_lines sl on sl.payable_event_id=pe.id
    join public.provider_invoices i on i.statement_id=sl.statement_id
    where m.contract_id=new.contract_id on conflict do nothing;
  end if;
  return new;
end$$;
revoke all on function private.project_client_invoice_deadline() from public,anon,authenticated,service_role;
create trigger provider_invoice_client_calendar_projection after insert on public.provider_invoices
for each row execute function private.project_client_invoice_deadline();
create trigger project_contract_invoice_calendar_projection after insert on public.client_project_contracts
for each row execute function private.project_client_invoice_deadline();
insert into public.client_invoice_calendar_items(organization_id,project_id,source_invoice_id,due_on)
select distinct pc.organization_id,pc.project_id,i.id,i.due_on
from public.client_project_contracts pc join public.missions m on m.contract_id=pc.contract_id
join public.provider_payable_events pe on pe.mission_id=m.id
join public.provider_statement_lines sl on sl.payable_event_id=pe.id
join public.provider_invoices i on i.statement_id=sl.statement_id
on conflict do nothing;

create function public.link_contract_to_client_project(
  p_project_id uuid,p_contract_id uuid,p_idempotency_key text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer
set search_path=pg_catalog,public,private,extensions as $$
declare
  a uuid:=auth.uid(); p public.client_projects%rowtype; c public.contracts%rowtype;
  h text; r jsonb; x uuid;
begin
  select * into p from public.client_projects where id=p_project_id;
  if a is null or not found or not private.client_portfolio_manage(p.organization_id,a) then
    raise exception 'CLIENT_PROJECT_CONTRACT_LINK_DENIED' using errcode='42501';
  end if;
  select * into c from public.contracts where id=p_contract_id;
  if not found or c.client_organization_id<>p.organization_id or c.status in('TERMINATED') then
    raise exception 'INVALID_CLIENT_PROJECT_CONTRACT' using errcode='22023';
  end if;
  h:=private.canonical_request_hash(jsonb_build_object('project',p.id,'contract',c.id));
  r:=private.begin_contract_command(p.organization_id,'client.project.contract.link',p_idempotency_key,h,a);
  if r is not null then return r; end if;
  if exists(select 1 from public.client_project_contracts where contract_id=c.id) then
    raise exception 'CONTRACT_ALREADY_LINKED' using errcode='23505';
  end if;
  insert into public.client_project_contracts(organization_id,project_id,contract_id,idempotency_key,correlation_id,linked_by)
  values(p.organization_id,p.id,c.id,p_idempotency_key,p_correlation_id,a) returning id into x;
  r:=jsonb_build_object('outcome','CLIENT_PROJECT_CONTRACT_LINKED','project_contract_id',x,'project_id',p.id,'contract_id',c.id);
  insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
  values(p.organization_id,a,'USER','client.project_contract.linked','client_project_contract',x::text,p_correlation_id,r,repeat('0',64));
  insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key)
  values(p.organization_id,'client_project',p.id::text,'ClientProjectContractLinkedV1',p_correlation_id,r,p_idempotency_key);
  perform private.finish_contract_command(p.organization_id,'client.project.contract.link',p_idempotency_key,r);
  return r;
end$$;

revoke all on function public.link_contract_to_client_project(uuid,uuid,text,uuid) from public,anon,service_role;
grant execute on function public.link_contract_to_client_project(uuid,uuid,text,uuid) to authenticated;

drop view public.client_central_calendar;
create function public.client_central_calendar_items()
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
  select pc.organization_id,pc.project_id,ms.id,'MISSION_MILESTONE','MISSION',ms.title_fr,ms.title_ar,
    ms.due_at,null::timestamptz,ms.status,null::date,false
  from public.client_project_contracts pc join public.missions m on m.contract_id=pc.contract_id
  join public.mission_milestones ms on ms.mission_id=m.id
  where ms.due_at is not null and private.client_portfolio_read(pc.organization_id)
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

create view public.client_central_calendar with(security_invoker=true) as
select * from public.client_central_calendar_items();
revoke all on public.client_central_calendar from public,anon;
grant select on public.client_central_calendar to authenticated;

create index client_project_contracts_project_idx on public.client_project_contracts(organization_id,project_id,linked_at desc);
create index client_project_contracts_contract_idx on public.client_project_contracts(contract_id,organization_id);
create index client_invoice_calendar_due_idx on public.client_invoice_calendar_items(organization_id,due_on,project_id);
create index quote_versions_calendar_idx on public.quote_versions(valid_until,quote_id) where lifecycle_status in('SUBMITTED','REVISED');
create index client_documents_calendar_idx on public.client_compliance_documents(organization_id,expires_on) where expires_on is not null;
