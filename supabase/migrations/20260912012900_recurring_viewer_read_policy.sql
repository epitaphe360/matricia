-- CLIENT_VIEWER can inspect its organization's recurring plans but cannot mutate them.
-- Command authorization remains on private.can_manage_client_request.

drop policy if exists recurring_plans_tenant_read
on public.recurring_service_plans;
create policy recurring_plans_tenant_read
on public.recurring_service_plans
for select
to authenticated
using (
  private.is_active_org_member(client_organization_id)
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'])
);

drop policy if exists recurring_plan_versions_tenant_read
on public.recurring_service_plan_versions;
create policy recurring_plan_versions_tenant_read
on public.recurring_service_plan_versions
for select
to authenticated
using (
  exists (
    select 1
    from public.recurring_service_plans plan
    where plan.id = plan_id
      and (
        private.is_active_org_member(plan.client_organization_id)
        or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'])
      )
  )
);

drop policy if exists recurring_occurrences_tenant_read
on public.recurring_service_occurrences;
create policy recurring_occurrences_tenant_read
on public.recurring_service_occurrences
for select
to authenticated
using (
  private.is_active_org_member(client_organization_id)
  or private.has_platform_role(array['SUPER_ADMIN','MATRICIA_ADMIN','READ_ONLY_AUDITOR'])
);

notify pgrst, 'reload schema';
