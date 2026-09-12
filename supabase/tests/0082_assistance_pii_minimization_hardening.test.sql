begin;
set local search_path=public,extensions;
select plan(16);

select is(private.minimize_assistance_input('ICE: 001234567890123'),'ICE: [ICE]','Moroccan ICE is category-redacted');
select is(private.minimize_assistance_input('IF: 12345678'),'IF: [IF]','Moroccan fiscal identifier is category-redacted');
select is(private.minimize_assistance_input('RC: Casablanca 12345'),'RC: [RC]','Moroccan commercial register is category-redacted');
select is(private.minimize_assistance_input('CNSS: 123456789'),'CNSS: [CNSS]','CNSS identifier is category-redacted');
select is(private.minimize_assistance_input('Nom: Jalil El Mansouri; dossier'),'Nom: [NAME]; dossier','labelled French name is redacted');
select is(private.minimize_assistance_input('الاسم: جليل المنصوري; ملف'),'الاسم: [NAME]; ملف','labelled Arabic name is redacted');
select is(private.minimize_assistance_input('Mme Asma El Idrissi; suivi'),'[NAME]; suivi','honorific name is redacted');
select is(private.minimize_assistance_input('Adresse: 12 rue Atlas, Rabat; audit'),'Adresse: [ADDRESS]; audit','labelled postal address is redacted');
select is(private.minimize_assistance_input('Rendez-vous au 12 rue Atlas, Rabat; demain'),'Rendez-vous au [ADDRESS]; demain','street-shaped address is redacted');
select is(private.minimize_assistance_input('العنوان: 24 شارع محمد الخامس; تدقيق'),'العنوان: [ADDRESS]; تدقيق','Arabic address is redacted');
select is(private.minimize_assistance_input('Email test.person@example.com téléphone +212 612 345 678'),'Email [EMAIL] téléphone [PHONE]','email and telephone remain redacted');
select is(private.minimize_assistance_input(private.minimize_assistance_input('Nom: Jalil El Mansouri; ICE: 001234567890123')),private.minimize_assistance_input('Nom: Jalil El Mansouri; ICE: 001234567890123'),'minimisation is deterministic and idempotent');
select ok(length(private.minimize_assistance_input(repeat('a',1200)))<=1000,'retained input is bounded to one thousand characters');
select ok((select p.provolatile='i'and not p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='minimize_assistance_input'),'minimizer is immutable and does not elevate privileges');
select ok(not has_function_privilege('authenticated','private.minimize_assistance_input(text)','EXECUTE')and not has_function_privilege('service_role','private.minimize_assistance_input(text)','EXECUTE'),'private minimizer is unavailable through API roles');
select ok((select p.prosrc like'%private.minimize_assistance_input(input_text)%'from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'and p.proname='run_assisted_analysis_runtime_v2')and not exists(select 1 from public.event_outbox where event_type like'Assistance%'and payload::text~'(001234567890123|test[.]person@example[.]com|Jalil El Mansouri|12 rue Atlas)'),'public analysis uses the hardened minimizer and Outbox exposes no adversarial PII');

select * from finish();rollback;
