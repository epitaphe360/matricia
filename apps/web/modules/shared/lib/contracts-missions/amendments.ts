import { z } from "zod";
import { resolveClientOrganizationContext } from "@/modules/shared/client-organization-context";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

const uuid = z.string().uuid();
const hash = z.string().regex(/^[0-9a-f]{64}$/);
const amount = z.union([z.string().regex(/^-?\d+$/), z.number().int().safe()]).transform(String);
const member = z.object({ organization_id: uuid });
const amendment = z.object({ id: uuid, contract_id: uuid, amendment_number: z.number().int().positive(), status: z.enum(["DRAFT", "PENDING_SIGNATURE", "ACTIVE", "REJECTED", "SUPERSEDED"]), price_delta_minor: amount, deadline_delta_days: z.number().int(), content_hash: hash, activated_contract_version_id: uuid.nullable(), created_at: z.string() });
const signature = z.object({ amendment_id: uuid, organization_id: uuid, signed_at: z.string() });

export type AmendmentDashboard = { organizationId: string; items: Array<{ id: string; contractId: string; number: number; status: z.infer<typeof amendment>["status"]; priceDeltaMinor: string; deadlineDeltaDays: number; contentHash: string; activatedContractVersionId: string | null; createdAt: string; signatures: Array<{ organizationId: string; signedAt: string }> }> };
type Result = { status: "success"; value: AmendmentDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "NO_CLIENT_ORGANIZATION" | "ORGANIZATION_SELECTION_REQUIRED" | "FORBIDDEN_ORGANIZATION" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadClientAmendments(requestedOrganizationId?: string): Promise<Result> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipResult = await client.from("organization_memberships").select("organization_id,organization_member_roles!inner(role_code,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", ["CLIENT_OWNER", "CLIENT_ADMIN"]).limit(100);
  if (membershipResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const memberships = z.array(member).max(100).safeParse(membershipResult.data);
  if (!memberships.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const context = resolveClientOrganizationContext(memberships.data, requestedOrganizationId);
  if (context.status === "error") return context;
  const organizationId = context.membership.organization_id;
  const contractsResult = await client.from("contracts").select("id").eq("client_organization_id", organizationId).limit(100);
  if (contractsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const contracts = z.array(z.object({ id: uuid })).max(100).safeParse(contractsResult.data);
  if (!contracts.success) return { status: "error", reason: "INVALID_RESPONSE" };
  if (!contracts.data.length) return { status: "success", value: { organizationId, items: [] } };
  const amendmentsResult = await client.from("contract_amendments").select("id,contract_id,amendment_number,status,price_delta_minor,deadline_delta_days,content_hash,activated_contract_version_id,created_at").in("contract_id", contracts.data.map((contract) => contract.id)).order("created_at", { ascending: false }).limit(200);
  if (amendmentsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const amendments = z.array(amendment).max(200).safeParse(amendmentsResult.data);
  if (!amendments.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const signaturesResult = amendments.data.length ? await client.from("contract_amendment_signatures").select("amendment_id,organization_id,signed_at").in("amendment_id", amendments.data.map((item) => item.id)).limit(400) : { data: [], error: null };
  if (signaturesResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const signatures = z.array(signature).max(400).safeParse(signaturesResult.data);
  if (!signatures.success) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", value: { organizationId, items: amendments.data.map((item) => ({ id: item.id, contractId: item.contract_id, number: item.amendment_number, status: item.status, priceDeltaMinor: item.price_delta_minor, deadlineDeltaDays: item.deadline_delta_days, contentHash: item.content_hash, activatedContractVersionId: item.activated_contract_version_id, createdAt: item.created_at, signatures: signatures.data.filter((signed) => signed.amendment_id === item.id).map((signed) => ({ organizationId: signed.organization_id, signedAt: signed.signed_at })) })) } };
}
