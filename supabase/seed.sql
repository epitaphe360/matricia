-- Schema-level seed gate; deterministic domain demo data is delivered in P18.
begin;
do $$
begin
  if (select count(*) from public.role_definitions)<>26 then
    raise exception 'REFERENCE_ROLE_SET_INVALID';
  end if;
  if not exists(select 1 from public.franchise_economic_rule_versions where franchise_type='IT' and status='ACTIVE' and entry_fee_minor=0 and franchisee_share_bps=5000 and neoxa_share_bps=5000 and matricia_share_bps=0) then
    raise exception 'REFERENCE_IT_FRANCHISE_RULE_REQUIRED';
  end if;
  if not exists(select 1 from public.franchise_economic_rule_versions where franchise_type='STANDARD' and status='ACTIVE' and franchisee_share_bps=5000 and neoxa_share_bps=2500 and matricia_share_bps=2500) then
    raise exception 'REFERENCE_STANDARD_FRANCHISE_RULE_REQUIRED';
  end if;
end;
$$;
commit;
