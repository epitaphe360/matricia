begin;
select plan(13);

select ok(to_regprocedure('public.schedule_recurring_service_requests(date,integer)') is not null,'bounded recurring scheduler exists');
select ok(not has_function_privilege('anon','public.schedule_recurring_service_requests(date,integer)','EXECUTE'),'anonymous cannot run recurring scheduler');
select ok(not has_function_privilege('authenticated','public.schedule_recurring_service_requests(date,integer)','EXECUTE'),'authenticated users cannot impersonate recurring scheduler');
select ok(has_function_privilege('service_role','public.schedule_recurring_service_requests(date,integer)','EXECUTE'),'service role may run recurring scheduler');
select ok((select p.prosecdef and p.proconfig::text like '%search_path=%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='schedule_recurring_service_requests'),'scheduler has fixed security-definer boundary');
select ok((select p.prosrc like '%p_limit not between 1 and 500%'and p.prosrc like '%order by p.id limit p_limit%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='schedule_recurring_service_requests'),'scheduler validates and deterministically bounds its batch');
select ok((select p.prosrc like '%iterations<24%'and(p.prosrc like '%max(occurrence.scheduled_on)%'or p.prosrc like '%max(o.scheduled_on)%')from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='schedule_recurring_service_requests'),'scheduler bounds each plan and resumes backlog after its latest occurrence');
select ok((select p.prosrc like '%pg_advisory_xact_lock%'and p.prosrc like '%on conflict(plan_id,scheduled_on)do nothing%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='schedule_recurring_service_requests'),'scheduler serializes plans and deduplicates occurrences');
select ok((select p.prosrc like '%autonomous_invitations%'and p.prosrc like '%autonomous_spend%'and p.prosrc not like '%insert into public.rfq_providers%'and p.prosrc not like '%financial_ledger%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='schedule_recurring_service_requests'),'scheduler only creates reviewable drafts without invitations or spend');

select ok((select p.prosrc like '%rfq-fair-rotation:%'and p.prosrc like '%pg_advisory_xact_lock%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='open_service_request_rfq'),'RFQ opening serializes fair rotation by service');
select ok((select p.prosrc like '%invitation_count asc%'and p.prosrc like '%last_invited_at asc nulls first%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='open_service_request_rfq'),'equivalent candidates prefer least and least-recently invited providers');
select ok((select p.prosrc like '%financial_status=''OK''%'and p.prosrc like '%quality_status=''OK''%'and p.prosrc like '%capacity_status in(''AVAILABLE'',''LIMITED'')%'and p.prosrc like '%qualification_status=''APPROVED''%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='open_service_request_rfq'),'invitation time revalidates provider qualification and capacity');
select ok((select p.prosrc like '%fair_rotation_policy%'and p.prosrc like '%event_outbox%'and p.prosrc like '%audit_events%' from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'and p.proname='open_service_request_rfq'),'fair rotation decision remains explainable, audited and outboxed');

select * from finish();
rollback;
