import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { providerMissionRows as row, type ProviderMissionDashboard } from "./model";

export type ProviderMissionsResult = { status: "success"; dashboard: ProviderMissionDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "NO_PROVIDER_ORGANIZATION" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadProviderMissions(locale: "fr" | "ar"): Promise<ProviderMissionsResult> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipResult = await client.from("organization_memberships").select("organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", ["PROVIDER_OWNER", "PROVIDER_MANAGER", "PROVIDER_TECHNICIAN"]).limit(1).maybeSingle();
  if (membershipResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const membership = row.membership.safeParse(membershipResult.data);
  if (!membership.success) return { status: "error", reason: membershipResult.data ? "INVALID_RESPONSE" : "NO_PROVIDER_ORGANIZATION" };
  const organizationId = membership.data.organization_id;
  const missionResult = await client.from("missions").select("id,contract_id,status,started_at,completed_at").eq("provider_organization_id", organizationId).order("updated_at", { ascending: false }).limit(100);
  if (missionResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const missions = z.array(row.mission).safeParse(missionResult.data);
  if (!missions.success) return { status: "error", reason: "INVALID_RESPONSE" };
  if (missions.data.length === 0) return { status: "success", dashboard: { organizationId, organizationName: membership.data.organizations.display_name, missions: [] } };
  const missionIds = missions.data.map((item) => item.id), contractIds = missions.data.map((item) => item.contract_id);
  const [milestoneResult, deliverableResult, contractResult, contractVersionResult] = await Promise.all([
    client.from("mission_milestones").select("id,mission_id,milestone_key,title_fr,title_ar,status,due_at").in("mission_id", missionIds).order("sort_order"),
    client.from("deliverables").select("id,mission_id,deliverable_key,label_fr,label_ar,proof_required,status,current_version").in("mission_id", missionIds),
    client.from("contracts").select("id,current_version").in("id", contractIds),
    client.from("contract_versions").select("contract_id,version,price_minor,currency,content_hash").in("contract_id", contractIds),
  ]);
  if (milestoneResult.error || deliverableResult.error || contractResult.error || contractVersionResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const milestones = z.array(row.milestone).safeParse(milestoneResult.data), deliverables = z.array(row.deliverable).safeParse(deliverableResult.data), contracts = z.array(row.contract).safeParse(contractResult.data), contractVersions = z.array(row.contractVersion).safeParse(contractVersionResult.data);
  if (!milestones.success || !deliverables.success || !contracts.success || !contractVersions.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const deliverableIds = deliverables.data.map((item) => item.id);
  const versionResult = deliverableIds.length ? await client.from("delivery_versions").select("id,deliverable_id,version,description,submitted_at,content_hash").in("deliverable_id", deliverableIds).order("version", { ascending: false }) : { data: [], error: null };
  if (versionResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const versions = z.array(row.version).safeParse(versionResult.data);
  if (!versions.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const versionIds = versions.data.map((item) => item.id);
  const proofResult = versionIds.length ? await client.from("delivery_proofs").select("delivery_version_id,scan_status").in("delivery_version_id", versionIds) : { data: [], error: null };
  if (proofResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const proofs = z.array(row.proof).safeParse(proofResult.data);
  if (!proofs.success) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", dashboard: { organizationId, organizationName: membership.data.organizations.display_name, missions: missions.data.map((mission) => {
    const contract = contracts.data.find((item) => item.id === mission.contract_id); const contractVersion = contractVersions.data.find((item) => item.contract_id === mission.contract_id && item.version === contract?.current_version);
    return { id: mission.id, contractId: mission.contract_id, status: mission.status, startedAt: mission.started_at, completedAt: mission.completed_at, contract: contract && contractVersion ? { currentVersion: contract.current_version, priceMinor: contractVersion.price_minor, currency: contractVersion.currency, contentHash: contractVersion.content_hash } : null,
      milestones: milestones.data.filter((item) => item.mission_id === mission.id).map((item) => ({ id: item.id, key: item.milestone_key, title: locale === "ar" ? item.title_ar : item.title_fr, status: item.status, dueAt: item.due_at })),
      deliverables: deliverables.data.filter((item) => item.mission_id === mission.id).map((item) => ({ id: item.id, key: item.deliverable_key, label: locale === "ar" ? item.label_ar : item.label_fr, proofRequired: item.proof_required, status: item.status, currentVersion: item.current_version, versions: versions.data.filter((version) => version.deliverable_id === item.id).map((version) => { const versionProofs=proofs.data.filter((proof) => proof.delivery_version_id === version.id); const proofScanStatus=versionProofs.length===0?"NONE":versionProofs.every((proof)=>proof.scan_status==="CLEAN")?"CLEAN":versionProofs.some((proof)=>proof.scan_status==="INFECTED")?"INFECTED":versionProofs.some((proof)=>proof.scan_status==="ERROR")?"ERROR":"PENDING"; return { id: version.id, version: version.version, description: version.description, submittedAt: version.submitted_at, contentHash: version.content_hash, proofCount: versionProofs.length, proofScanStatus }; }) })) };
  }) } };
}
