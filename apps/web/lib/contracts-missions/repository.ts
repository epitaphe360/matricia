import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { ContractItemType, ContractMissionDashboard } from "./model";

const id = z.string().uuid();
const hash = z.string().regex(/^[0-9a-f]{64}$/);
const amount = z.union([z.string().regex(/^-?\d+$/), z.number().int().safe()]).transform((value): string => String(value));
const member = z.object({ organization_id: id, organizations: z.object({ display_name: z.string().min(1) }) });
const contractRow = z.object({ id, provider_organization_id: id, status: z.string(), current_version: z.number().int().positive(), row_version: z.number().int().positive() });
const versionRow = z.object({ id, contract_id: id, version: z.number().int().positive(), selected_quote_version_id: id, price_minor: amount, currency: z.string().regex(/^[A-Z]{3}$/), content_hash: hash, change_reason: z.string().min(3), created_at: z.string() });
const signatureRow = z.object({ id, contract_id: id, contract_version_id: id, organization_id: id, signer_role: z.string().min(1), contract_hash: hash, signed_at: z.string(), proof: z.object({ method: z.string().min(1), evidence_hash: hash }).passthrough() });
const itemType = z.enum(["DELIVERABLE", "EXCLUSION", "ACCEPTANCE_CRITERION", "PAYMENT_TERM", "CORRECTION", "PENALTY"]);
const itemRow = z.object({ id, contract_version_id: id, item_key: z.string(), item_type: itemType, label_fr: z.string().min(1), label_ar: z.string().min(1), sort_order: z.number().int().positive() });
const missionRow = z.object({ id, contract_id: id, contract_version_id: id, status: z.string(), started_at: z.string().nullable(), completed_at: z.string().nullable() });
const milestoneRow = z.object({ id, mission_id: id, milestone_key: z.string(), title_fr: z.string(), title_ar: z.string(), status: z.string(), due_at: z.string().nullable() });
const deliverableRow = z.object({ id, mission_id: id, deliverable_key: z.string(), label_fr: z.string(), label_ar: z.string(), status: z.string(), current_version: z.number().int().nonnegative() });
const criterionRow = z.object({ deliverable_id: id, criterion_key: z.string(), status: z.string() });

type LoadResult = { status: "success"; dashboard: ContractMissionDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "NO_CLIENT_ORGANIZATION" | "QUERY_FAILED" | "INVALID_RESPONSE" };
function rows<T>(schema: z.ZodType<T>, value: unknown, max: number) {
  return z.array(schema).max(max).safeParse(value);
}

export async function loadContractMissions(locale: "fr" | "ar"): Promise<LoadResult> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipResult = await client.from("organization_memberships").select("organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", ["CLIENT_OWNER", "CLIENT_ADMIN"]).limit(1).maybeSingle();
  if (membershipResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const membership = member.safeParse(membershipResult.data);
  if (!membership.success) return { status: "error", reason: membershipResult.data ? "INVALID_RESPONSE" : "NO_CLIENT_ORGANIZATION" };
  const organizationId = membership.data.organization_id;

  const contractsResult = await client.from("contracts").select("id,provider_organization_id,status,current_version,row_version").eq("client_organization_id", organizationId).order("created_at", { ascending: false }).limit(100);
  if (contractsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const contracts = rows(contractRow, contractsResult.data, 100);
  if (!contracts.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const contractIds = contracts.data.map((contract) => contract.id);
  if (contractIds.length === 0) return { status: "success", dashboard: { organizationId, organizationName: membership.data.organizations.display_name, contracts: [], missions: [] } };

  const [versionsResult, signaturesResult, missionsResult] = await Promise.all([
    client.from("contract_versions").select("id,contract_id,version,selected_quote_version_id,price_minor,currency,content_hash,change_reason,created_at").in("contract_id", contractIds).order("version", { ascending: false }).limit(500),
    client.from("contract_signatures").select("id,contract_id,contract_version_id,organization_id,signer_role,contract_hash,signed_at,proof").in("contract_id", contractIds).limit(200),
    client.from("missions").select("id,contract_id,contract_version_id,status,started_at,completed_at").eq("client_organization_id", organizationId).in("contract_id", contractIds).order("created_at", { ascending: false }).limit(100),
  ]);
  if (versionsResult.error || signaturesResult.error || missionsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const versions = rows(versionRow, versionsResult.data, 500), signatures = rows(signatureRow, signaturesResult.data, 200), missions = rows(missionRow, missionsResult.data, 100);
  if (!versions.success || !signatures.success || !missions.success) return { status: "error", reason: "INVALID_RESPONSE" };

  const versionIds = versions.data.map((version) => version.id);
  const missionIds = missions.data.map((mission) => mission.id);
  const [itemsResult, milestonesResult, deliverablesResult] = await Promise.all([
    client.from("contract_items").select("id,contract_version_id,item_key,item_type,label_fr,label_ar,sort_order").in("contract_version_id", versionIds).order("sort_order").limit(1000),
    missionIds.length ? client.from("mission_milestones").select("id,mission_id,milestone_key,title_fr,title_ar,status,due_at").in("mission_id", missionIds).order("sort_order").limit(500) : Promise.resolve({ data: [], error: null }),
    missionIds.length ? client.from("deliverables").select("id,mission_id,deliverable_key,label_fr,label_ar,status,current_version").in("mission_id", missionIds).limit(500) : Promise.resolve({ data: [], error: null }),
  ]);
  if (itemsResult.error || milestonesResult.error || deliverablesResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const items = rows(itemRow, itemsResult.data, 1000), milestones = rows(milestoneRow, milestonesResult.data, 500), deliverables = rows(deliverableRow, deliverablesResult.data, 500);
  if (!items.success || !milestones.success || !deliverables.success) return { status: "error", reason: "INVALID_RESPONSE" };

  const deliverableIds = deliverables.data.map((deliverable) => deliverable.id);
  const criteriaResult = deliverableIds.length ? await client.from("acceptance_checklists").select("deliverable_id,criterion_key,status").in("deliverable_id", deliverableIds).limit(1000) : { data: [], error: null };
  if (criteriaResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const criteria = rows(criterionRow, criteriaResult.data, 1000);
  if (!criteria.success) return { status: "error", reason: "INVALID_RESPONSE" };
  if (missions.data.some((mission) => !versions.data.some((version) => version.id === mission.contract_version_id && version.contract_id === mission.contract_id))) return { status: "error", reason: "INVALID_RESPONSE" };

  const localizedItems = (contractVersionId: string) => items.data.filter((item) => item.contract_version_id === contractVersionId).map((item) => ({ id: item.id, key: item.item_key, type: item.item_type as ContractItemType, label: locale === "ar" ? item.label_ar : item.label_fr, sortOrder: item.sort_order }));
  const versionSignatures = (contractVersionId: string) => signatures.data.filter((signature) => signature.contract_version_id === contractVersionId).map((signature) => ({ id: signature.id, organizationId: signature.organization_id, signerRole: signature.signer_role, contractHash: signature.contract_hash, signedAt: signature.signed_at, method: signature.proof.method, evidenceHash: signature.proof.evidence_hash }));

  return { status: "success", dashboard: {
    organizationId,
    organizationName: membership.data.organizations.display_name,
    contracts: contracts.data.flatMap((contract) => {
      const history = versions.data.filter((version) => version.contract_id === contract.id).sort((left, right) => right.version - left.version);
      const current = history.find((version) => version.version === contract.current_version);
      if (!current) return [];
      return [{
        id: contract.id,
        providerOrganizationId: contract.provider_organization_id,
        status: contract.status,
        currentVersion: contract.current_version,
        rowVersion: contract.row_version,
        versionId: current.id,
        selectedQuoteVersionId: current.selected_quote_version_id,
        priceMinor: String(current.price_minor),
        currency: current.currency,
        contentHash: current.content_hash,
        changeReason: current.change_reason,
        createdAt: current.created_at,
        signatureCount: versionSignatures(current.id).length,
        signatures: versionSignatures(current.id),
        items: localizedItems(current.id),
        history: history.map((version) => ({ id: version.id, version: version.version, selectedQuoteVersionId: version.selected_quote_version_id, priceMinor: String(version.price_minor), currency: version.currency, contentHash: version.content_hash, changeReason: version.change_reason, createdAt: version.created_at })),
      }];
    }),
    missions: missions.data.flatMap((mission) => {
      const contractVersion = versions.data.find((version) => version.id === mission.contract_version_id && version.contract_id === mission.contract_id);
      if (!contractVersion) return [];
      return [{
        id: mission.id,
        contractId: mission.contract_id,
        contractVersionId: mission.contract_version_id,
        contractSnapshot: { versionId: contractVersion.id, version: contractVersion.version, selectedQuoteVersionId: contractVersion.selected_quote_version_id, priceMinor: String(contractVersion.price_minor), currency: contractVersion.currency, contentHash: contractVersion.content_hash, changeReason: contractVersion.change_reason, createdAt: contractVersion.created_at, items: localizedItems(contractVersion.id), signatures: versionSignatures(contractVersion.id) },
        status: mission.status,
        startedAt: mission.started_at,
        completedAt: mission.completed_at,
        milestones: milestones.data.filter((milestone) => milestone.mission_id === mission.id).map((milestone) => ({ id: milestone.id, key: milestone.milestone_key, title: locale === "ar" ? milestone.title_ar : milestone.title_fr, status: milestone.status, dueAt: milestone.due_at })),
        deliverables: deliverables.data.filter((deliverable) => deliverable.mission_id === mission.id).map((deliverable) => ({ id: deliverable.id, key: deliverable.deliverable_key, label: locale === "ar" ? deliverable.label_ar : deliverable.label_fr, status: deliverable.status, currentVersion: deliverable.current_version, criteria: criteria.data.filter((criterion) => criterion.deliverable_id === deliverable.id).map((criterion) => ({ key: criterion.criterion_key, status: criterion.status })) })),
      }];
    }),
  } };
}
