-- Choice options may be completed in Builder while a version is DRAFT. All
-- publishable states retain the strict non-empty choice contract.

alter table public.question_versions drop constraint question_versions_check;
alter table public.question_versions add constraint question_versions_choice_contract_check check (
 (answer_type in ('SINGLE_CHOICE','MULTIPLE_CHOICE') and (status='DRAFT' or jsonb_array_length(options)>0))
 or (answer_type not in ('SINGLE_CHOICE','MULTIPLE_CHOICE') and jsonb_array_length(options)=0)
);

