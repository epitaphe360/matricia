-- NON-PRODUCTION ONLY — retires the test rules created by test-activate-tax-rules.sql.
-- ACTIVE→RETIRED is the only transition allowed by the tax rule immutability guard;
-- retired rules stay available as historical source rules for already-issued invoices and credit notes.

update public.tax_rule_versions
set status = 'RETIRED'
where jurisdiction_code = 'MA'
  and status = 'ACTIVE'
  and validation_reference = 'TEST-NON-PROD'
  and conditions->>'environment_class' = 'NON_PRODUCTION_TEST';

select category_code, version, status, validation_reference
from public.tax_rule_versions
where jurisdiction_code = 'MA' and validation_reference = 'TEST-NON-PROD'
order by category_code, version;
