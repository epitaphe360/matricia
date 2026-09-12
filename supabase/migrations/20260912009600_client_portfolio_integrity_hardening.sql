-- Additive integrity hardening for MAT-FUNC-011/012/021/053.
-- Fail closed for assignees, state transitions and polymorphic client references.

create function private.client_invoice_belongs_to(p_organization_id uuid,p_invoice_id uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
 select exists(
  select 1 from public.provider_invoices i
  join public.provider_statement_lines l on l.statement_id=i.statement_id and l.provider_organization_id=i.provider_organization_id
  join public.provider_payable_events e on e.id=l.payable_event_id and e.provider_organization_id=l.provider_organization_id
  where i.id=p_invoice_id and e.client_organization_id=p_organization_id
 ) and not exists(
  select 1 from public.provider_invoices i
  join public.provider_statement_lines l on l.statement_id=i.statement_id and l.provider_organization_id=i.provider_organization_id
  join public.provider_payable_events e on e.id=l.payable_event_id and e.provider_organization_id=l.provider_organization_id
  where i.id=p_invoice_id and e.client_organization_id<>p_organization_id
 )
$$;

create function private.client_typed_reference_valid(p_organization_id uuid,p_reference_type text,p_reference_id uuid,p_project_id uuid default null)
returns boolean language plpgsql stable security definer set search_path=pg_catalog,public,private as $$
begin
 if p_reference_type='MANUAL'then return p_reference_id is null;end if;
 if p_reference_id is null then return false;end if;
 case p_reference_type
  when'PROJECT'then return exists(select 1 from public.client_projects p where p.id=p_reference_id and p.organization_id=p_organization_id and(p_project_id is null or p.id=p_project_id));
  when'PROJECT_TASK'then return exists(select 1 from public.client_project_tasks t where t.id=p_reference_id and t.organization_id=p_organization_id and(p_project_id is null or t.project_id=p_project_id));
  when'CONTRACT'then return exists(select 1 from public.contracts c where c.id=p_reference_id and c.client_organization_id=p_organization_id);
  when'MISSION'then return exists(select 1 from public.missions m where m.id=p_reference_id and m.client_organization_id=p_organization_id);
  when'MISSION_MILESTONE'then return exists(select 1 from public.mission_milestones x join public.missions m on m.id=x.mission_id where x.id=p_reference_id and m.client_organization_id=p_organization_id);
  when'INVOICE'then return private.client_invoice_belongs_to(p_organization_id,p_reference_id);
  when'DOCUMENT'then return exists(select 1 from public.client_compliance_documents d where d.id=p_reference_id and d.organization_id=p_organization_id);
  when'RFQ'then return exists(select 1 from public.service_requests r where r.id=p_reference_id and r.client_organization_id=p_organization_id);
  else return false;
 end case;
end$$;

create function private.enforce_client_task_assignee_tenant()returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
begin
 if new.assignee_user_id is not null and not private.is_active_org_member(new.organization_id,new.assignee_user_id)then
  raise exception'CLIENT_TASK_ASSIGNEE_OUTSIDE_TENANT'using errcode='23514';
 end if;
 return new;
end$$;
create trigger client_task_assignee_tenant_guard before insert or update of organization_id,assignee_user_id on public.client_project_tasks for each row execute function private.enforce_client_task_assignee_tenant();

create function private.enforce_client_project_state_transition()returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
 if new.status=old.status then return new;end if;
 if not(
  (old.status='DRAFT'and new.status in('PLANNED','CANCELLED'))or
  (old.status='PLANNED'and new.status in('ACTIVE','ON_HOLD','CANCELLED'))or
  (old.status='ACTIVE'and new.status in('ON_HOLD','COMPLETED','CANCELLED'))or
  (old.status='ON_HOLD'and new.status in('ACTIVE','CANCELLED'))
 )then raise exception'INVALID_CLIENT_PROJECT_TRANSITION'using errcode='55000';end if;
 return new;
end$$;
create trigger client_project_state_machine before update of status on public.client_projects for each row execute function private.enforce_client_project_state_transition();

create function private.enforce_client_cost_allocation_reference()returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
begin
 if not private.client_typed_reference_valid(new.organization_id,new.reference_type,new.reference_id,new.project_id)then
  raise exception'CLIENT_COST_REFERENCE_OUTSIDE_TENANT_OR_INVALID'using errcode='23514';
 end if;
 return new;
end$$;
create trigger client_cost_allocation_reference_guard before insert or update of organization_id,reference_type,reference_id,project_id on public.client_cost_allocations for each row execute function private.enforce_client_cost_allocation_reference();

create function private.enforce_client_calendar_source()returns trigger language plpgsql security definer set search_path=pg_catalog,public,private as $$
begin
 if new.source_type is null and new.source_id is null then return new;end if;
 if new.source_type not in('PROJECT','PROJECT_TASK','CONTRACT','MISSION','MISSION_MILESTONE','INVOICE','DOCUMENT','RFQ')
  or not private.client_typed_reference_valid(new.organization_id,new.source_type,new.source_id,new.project_id)then
  raise exception'CLIENT_CALENDAR_SOURCE_OUTSIDE_TENANT_OR_INVALID'using errcode='23514';
 end if;
 return new;
end$$;
create trigger client_calendar_source_guard before insert or update of organization_id,project_id,source_type,source_id on public.client_calendar_events for each row execute function private.enforce_client_calendar_source();

revoke all on function private.client_invoice_belongs_to(uuid,uuid),private.client_typed_reference_valid(uuid,text,uuid,uuid),private.enforce_client_task_assignee_tenant(),private.enforce_client_project_state_transition(),private.enforce_client_cost_allocation_reference(),private.enforce_client_calendar_source()from public,anon,authenticated,service_role;
