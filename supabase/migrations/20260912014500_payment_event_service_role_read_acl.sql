begin;

revoke all on table public.subscription_payment_events from public, anon, authenticated, service_role;
grant select on table public.subscription_payment_events to service_role;

commit;
