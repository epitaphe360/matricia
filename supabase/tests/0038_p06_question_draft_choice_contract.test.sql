begin;
set local search_path=public,extensions;
select plan(3);

select ok((select pg_get_constraintdef(oid) like '%status = ''DRAFT''%' from pg_constraint where conrelid='public.question_versions'::regclass and conname='question_versions_choice_contract_check'),'DRAFT choice versions may await Builder options');
select ok(not private.is_valid_typed_question_metadata('SINGLE_CHOICE','[]'::jsonb,'{}'::jsonb,'{}'::jsonb,null),'empty choice metadata remains unpublishable');
select ok(private.is_valid_typed_question_metadata('SINGLE_CHOICE','["STANDARD","DETAILED"]'::jsonb,'{}'::jsonb,'{}'::jsonb,null),'completed choice metadata remains publishable');

select * from finish();
rollback;
