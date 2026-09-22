import { z } from "zod";
import { hasPlatformRole, loadMyPlatformAccess } from "@/modules/shared/lib/account-security/platform-access";

const list = z.array(z.record(z.string(), z.unknown()));
export type AdminIncentives = { organizations:Record<string,unknown>[];rules:Record<string,unknown>[];policies:Record<string,unknown>[];evaluations:Record<string,unknown>[];decisions:Record<string,unknown>[];reputations:Record<string,unknown>[];reputationPolicies:Record<string,unknown>[];serviceVersions:Record<string,unknown>[] };
export async function loadAdminIncentives():Promise<{status:"success";value:AdminIncentives}|{status:"error";reason:"UNAUTHENTICATED"|"MFA_REQUIRED"|"FORBIDDEN"|"UNAVAILABLE"}>{
 const access=await loadMyPlatformAccess();if(access.status==="error")return{status:"error",reason:access.reason==="UNAUTHENTICATED"?"UNAUTHENTICATED":"UNAVAILABLE"};
 if(!hasPlatformRole(access.roles,["SUPER_ADMIN","MATRICIA_ADMIN"]))return{status:"error",reason:"FORBIDDEN"};
 if(!access.requirementSatisfied)return{status:"error",reason:"MFA_REQUIRED"};
 const c=access.client;
 const q=await Promise.all([
  c.from("organizations").select("id,display_name,kind,status").eq("status","ACTIVE").order("display_name").limit(300),
  c.from("reward_rule_versions").select("id,rule_code,version_number,status,trigger_event,audience_type,bonus_credits,per_recipient_cap_credits,global_cap_credits,window_days,cooldown_hours,credit_validity_days,requires_approval,effective_from,effective_until,change_reason").order("created_at",{ascending:false}).limit(300),
  c.from("provider_badge_policy_versions").select("id,badge_code,version_number,label_fr,label_ar,dimension,minimum_basis_points,minimum_evidence_count,effective_from,effective_until").order("created_at",{ascending:false}).limit(300),
  c.from("provider_badge_evaluations").select("id,provider_organization_id,service_id,badge_policy_id,reputation_snapshot_id,evaluation_version,eligible,evaluated_basis_points,evaluated_at").order("evaluated_at",{ascending:false}).limit(300),
  c.from("provider_badge_decisions").select("id,evaluation_id,provider_organization_id,decision_version,action,rationale,decided_at").order("decision_version",{ascending:false}).limit(500),
  c.from("provider_reputation_snapshots").select("id,provider_organization_id,service_id,version_number,overall_basis_points,evidence_count,calculated_at").order("calculated_at",{ascending:false}).limit(500),
  c.from("provider_reputation_policy_versions").select("policy_version,effective_from,effective_until").order("effective_from",{ascending:false}).limit(50),
  c.from("catalog_service_versions").select("id,service_id,version,name_fr,name_ar,status").eq("status","PUBLISHED").order("name_fr").limit(500),
 ]);
 if(q.some(x=>x.error))return{status:"error",reason:"UNAVAILABLE"};const p=q.map(x=>list.safeParse(x.data));if(p.some(x=>!x.success))return{status:"error",reason:"UNAVAILABLE"};
 return{status:"success",value:{organizations:p[0]!.data!,rules:p[1]!.data!,policies:p[2]!.data!,evaluations:p[3]!.data!,decisions:p[4]!.data!,reputations:p[5]!.data!,reputationPolicies:p[6]!.data!,serviceVersions:p[7]!.data!}};
}
