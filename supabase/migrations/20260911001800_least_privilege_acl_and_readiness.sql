-- Remove inherited Supabase grants that can bypass RLS or immutable triggers.
revoke all privileges on all tables in schema public from anon,authenticated,service_role;
revoke all privileges on all sequences in schema public from anon,authenticated,service_role;
alter default privileges for role postgres in schema public revoke all on tables from anon,authenticated,service_role;
alter default privileges for role postgres in schema public revoke all on sequences from anon,authenticated,service_role;

grant select on public.role_definitions,public.tax_rule_versions,public.franchise_economic_rule_versions to authenticated;
grant select on public.organizations,public.organization_identifiers,public.organization_memberships,public.organization_member_roles to authenticated;
grant select on public.user_profiles to authenticated;
grant update(display_name,preferred_locale) on public.user_profiles to authenticated;
grant select on public.financial_accounts,public.financial_journals,public.financial_entries to authenticated;
grant select on public.credit_wallets,public.credit_ledger_entries,public.credit_wallet_balances to authenticated;
grant select on public.audit_events,public.organization_audit_activity to authenticated;
grant select on public.organization_access_requests,public.organization_invitations,public.organization_invitation_roles to authenticated;

create or replace function public.readiness_status()
returns table(database_ok boolean,outbox_ok boolean,pending_events bigint,oldest_pending_seconds bigint)
language plpgsql stable security definer set search_path=pg_catalog,public
as $$
begin
  if auth.role()<>'service_role' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  return query
    select true,
      coalesce(min(o.occurred_at) filter(where o.published_at is null and o.dead_lettered_at is null) > statement_timestamp()-interval '24 hours',true),
      count(*) filter(where o.published_at is null and o.dead_lettered_at is null),
      coalesce(extract(epoch from statement_timestamp()-min(o.occurred_at) filter(where o.published_at is null and o.dead_lettered_at is null))::bigint,0)
    from public.event_outbox o;
end;
$$;
revoke all on function public.readiness_status() from public,anon,authenticated;
grant execute on function public.readiness_status() to service_role;
notify pgrst,'reload schema';
