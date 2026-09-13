begin;
set local search_path = public, extensions;
select plan(8);

select has_function('private','is_valid_questionnaire_document_references',array['text','jsonb','jsonb','uuid'],'document-reference validator exists');
select has_trigger('public','questionnaire_answer_revisions','questionnaire_answer_revision_document_scope','answer revision trigger enforces document scope');

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('e9400000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','qdoc-a@example.invalid','',now(),'{}','{}',now(),now()),
('e9400000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','qdoc-b@example.invalid','',now(),'{}','{}',now(),now());
insert into public.organizations(id,legal_name,display_name,status,created_by) values
('e9410000-0000-0000-0000-000000000001','Questionnaire Documents A','QDoc A','PENDING','e9400000-0000-0000-0000-000000000001'),
('e9410000-0000-0000-0000-000000000002','Questionnaire Documents B','QDoc B','PENDING','e9400000-0000-0000-0000-000000000002');
insert into public.client_compliance_cases(id,organization_id,created_by) values
('e9420000-0000-0000-0000-000000000001','e9410000-0000-0000-0000-000000000001','e9400000-0000-0000-0000-000000000001'),
('e9420000-0000-0000-0000-000000000002','e9410000-0000-0000-0000-000000000002','e9400000-0000-0000-0000-000000000002');
insert into public.client_compliance_documents(id,compliance_case_id,organization_id,document_type,version,policy_version_id,document_number,issuer,issued_on,original_file_name,file_extension,declared_mime_type,declared_size_bytes,declared_sha256,storage_object_path,status,uploaded_at,created_by) values
('e9430000-0000-0000-0000-000000000001','e9420000-0000-0000-0000-000000000001','e9410000-0000-0000-0000-000000000001','TAX_DOCUMENT',1,(select id from public.client_document_policy_versions where document_type='TAX_DOCUMENT' and status='ACTIVE' limit 1),'IF-A','DGI',date '2026-01-01','a.pdf','pdf','application/pdf',100,repeat('a',64),'e9410000-0000-0000-0000-000000000001/questionnaire/a.pdf','PENDING_REVIEW',now(),'e9400000-0000-0000-0000-000000000001'),
('e9430000-0000-0000-0000-000000000002','e9420000-0000-0000-0000-000000000001','e9410000-0000-0000-0000-000000000001','REGISTRATION_DOCUMENT',1,(select id from public.client_document_policy_versions where document_type='REGISTRATION_DOCUMENT' and status='ACTIVE' limit 1),'RC-A','Tribunal',date '2026-01-01','a.png','png','image/png',100,repeat('b',64),'e9410000-0000-0000-0000-000000000001/questionnaire/a.png','PENDING_REVIEW',now(),'e9400000-0000-0000-0000-000000000001'),
('e9430000-0000-0000-0000-000000000003','e9420000-0000-0000-0000-000000000002','e9410000-0000-0000-0000-000000000002','TAX_DOCUMENT',1,(select id from public.client_document_policy_versions where document_type='TAX_DOCUMENT' and status='ACTIVE' limit 1),'IF-B','DGI',date '2026-01-01','b.pdf','pdf','application/pdf',100,repeat('c',64),'e9410000-0000-0000-0000-000000000002/questionnaire/b.pdf','PENDING_REVIEW',now(),'e9400000-0000-0000-0000-000000000002');

select ok(private.is_valid_questionnaire_document_references('FILE'::text,null::jsonb,to_jsonb('e9430000-0000-0000-0000-000000000001'::text),'e9410000-0000-0000-0000-000000000001'::uuid),'same-organization admissible file is accepted');
select ok(not private.is_valid_questionnaire_document_references('FILE'::text,null::jsonb,to_jsonb('e9430000-0000-0000-0000-000000000003'::text),'e9410000-0000-0000-0000-000000000001'::uuid),'foreign-organization file is rejected');
select ok(private.is_valid_questionnaire_document_references('IMAGE'::text,null::jsonb,to_jsonb('e9430000-0000-0000-0000-000000000002'::text),'e9410000-0000-0000-0000-000000000001'::uuid),'same-organization image MIME is accepted');
select ok(not private.is_valid_questionnaire_document_references('IMAGE'::text,null::jsonb,to_jsonb('e9430000-0000-0000-0000-000000000001'::text),'e9410000-0000-0000-0000-000000000001'::uuid),'non-image document cannot answer IMAGE');
select ok(not private.is_valid_questionnaire_document_references('MULTI_FILE'::text,null::jsonb,'["e9430000-0000-0000-0000-000000000001","e9430000-0000-0000-0000-000000000003"]'::jsonb,'e9410000-0000-0000-0000-000000000001'::uuid),'mixed-tenant multi-file answer is rejected');
select ok(not private.is_valid_questionnaire_document_references('TABLE'::text,'{"columns":[{"key":"proof","type":"FILE"}]}'::jsonb,'[{"proof":"e9430000-0000-0000-0000-000000000003"}]'::jsonb,'e9410000-0000-0000-0000-000000000001'::uuid),'nested foreign file in TABLE is rejected');

select * from finish();
rollback;
