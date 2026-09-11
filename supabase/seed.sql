-- Schema-level seed gate; deterministic domain demo data is delivered in P18.
begin;
do $$
begin
  if (select count(*) from public.role_definitions)=0 then
    raise exception 'REFERENCE_ROLES_REQUIRED';
  end if;
  if (select count(*) from public.tax_rule_versions)=0 then
    raise exception 'REFERENCE_TAX_RULE_REQUIRED';
  end if;
end;
$$;
commit;
