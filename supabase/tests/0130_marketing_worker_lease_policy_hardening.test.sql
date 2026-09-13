begin;
set local search_path=public,extensions;
select plan(10);

select has_column('public','social_publication_jobs','claimed_by','jobs record the claiming worker');
select has_column('public','social_publication_jobs','claimed_at','jobs record claim time');
select has_column('public','social_publication_jobs','lease_expires_at','jobs have a bounded lease');
select has_index('public','social_publication_jobs','social_publication_jobs_lease_idx','expired claims are indexed');
select isnt_empty($$select 1 from pg_get_functiondef('public.claim_next_social_publication_job_v41(text,uuid)'::regprocedure)d
  where d like'%lease_expires_at%'and d like'%reclaimed%'$$,
  'claim worker recovers expired leases and returns recovery evidence');
select isnt_empty($$select 1 from pg_get_functiondef('public.claim_next_social_publication_job_v41(text,uuid)'::regprocedure)d
  where d like'%PUBLICATION_POLICY_BLOCKED%'and d like'%SocialPublicationPolicyBlockedV1%'
  and d like'%marketing.publication.policy_blocked%'$$,
  'policy blocks create an exception, audit and outbox event');
select isnt_empty($$select 1 from pg_get_functiondef('private.marketing_publication_ready_v41(uuid,text,uuid,uuid)'::regprocedure)d
  where d like'%source%'and d like'%brand%'and d like'%claims%'and d like'%promotion%'and d like'%duplicate%'$$,
  'publication readiness requires every compliance family');
select isnt_empty($$select 1 from pg_get_functiondef('private.marketing_publication_ready_v41(uuid,text,uuid,uuid)'::regprocedure)d
  where d like'%authorization_scope@>array[''SOCIAL_PUBLISHING'']%'$$,
  'brand authorization explicitly covers social publishing');
select isnt_empty($$select 1 from pg_get_functiondef('private.marketing_publication_ready_v41(uuid,text,uuid,uuid)'::regprocedure)d
  where d like'%content.channel%'and d like'%connection.scopes%'and d like'%instagram_content_publish%'
  and d like'%w_member_social%'$$,
  'provider scopes match the stored grant and the exact destination channel');
select function_privs_are('public','claim_next_social_publication_job_v41',array['text','uuid'],
  'service_role',array['EXECUTE'],'worker claim remains service-role only');

select * from finish();
rollback;
