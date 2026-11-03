-- Match the Provider current-family invariant: an older version does not become
-- current again merely because the latest version targets another library.
-- Historical private-document access remains independently authorized.
begin;
do $migration$
declare definition text;anchor text:='where d.provider_organization_id=p.provider_organization_id and exists(';
begin
 definition:=pg_get_functiondef('public.franchise_provider_dossiers(uuid)'::regprocedure);
 if(length(definition)-length(replace(definition,anchor,'')))/length(anchor)<>1 then raise exception 'FRANCHISE_CURRENT_DOCUMENT_SOURCE_MISMATCH';end if;
 definition:=replace(definition,anchor,'where d.provider_organization_id=p.provider_organization_id and not exists(select 1 from public.provider_document_versions newer where newer.family_id=d.family_id and newer.version_number>d.version_number)and exists(');
 execute definition;
end$migration$;
commit;
