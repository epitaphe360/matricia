-- Additive ACL repair for policy helpers already deployed on development.
revoke all on function
  private.contract_party_access(uuid,uuid),
  private.mission_party_access(uuid,uuid),
  private.provider_billing_access(uuid,uuid),
  private.dispute_case_access(uuid,uuid),
  private.dispute_evidence_access(uuid,uuid),
  private.dispute_financial_access(uuid,uuid),
  private.dispute_reassignment_access(uuid,uuid),
  private.volume_admin_access(uuid),
  private.volume_pool_read_access(uuid,uuid)
from public,anon,authenticated,service_role;

grant execute on function
  private.contract_party_access(uuid,uuid),
  private.mission_party_access(uuid,uuid),
  private.provider_billing_access(uuid,uuid),
  private.dispute_case_access(uuid,uuid),
  private.dispute_evidence_access(uuid,uuid),
  private.dispute_financial_access(uuid,uuid),
  private.dispute_reassignment_access(uuid,uuid),
  private.volume_admin_access(uuid),
  private.volume_pool_read_access(uuid,uuid)
to authenticated;
