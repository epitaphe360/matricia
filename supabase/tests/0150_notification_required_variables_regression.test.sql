begin;
select plan(3);
select ok(pg_get_functiondef('public.enqueue_notification(uuid,uuid,text,text,text,jsonb,text,text,text,uuid)'::regprocedure) like '%MISSING_NOTIFICATION_VARIABLE%','missing template variables are rejected');
select ok(pg_get_functiondef('public.enqueue_notification(uuid,uuid,text,text,text,jsonb,text,text,text,uuid)'::regprocedure) like '%notification_email_consent_active%','email consent guard is preserved');
select ok(pg_get_functiondef('public.enqueue_notification(uuid,uuid,text,text,text,jsonb,text,text,text,uuid)'::regprocedure) like '%notification_mandatory_policy_versions%','mandatory legal basis is preserved');
select * from finish();
rollback;
