import { z } from "zod";
import { resolveClientOrganizationContext } from "@/modules/shared/client-organization-context";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { VolumeDashboard } from "./model";

const id = z.string().uuid();
const exact = z.string().regex(/^\d+(?:\.\d+)?$/);
const member = z.object({ organization_id: id, organizations: z.object({ display_name: z.string().min(1) }) });
const pool = z.object({ id, agreement_id: id, agreement_version_id: id, contracted_units: exact, available_units: exact, reserved_units: exact, committed_units: exact, consumed_units: exact, released_units: exact, status: z.string(), window_end: z.string(), row_version: exact });
const reservation = z.object({ id, pool_id: id, client_organization_id: id, benefit_reference: z.string(), reserved_units: exact, consumed_units: exact, released_units: exact, status: z.string(), expires_at: z.string() });
type Result = { status: "success"; dashboard: VolumeDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "NO_CLIENT_ORGANIZATION" | "ORGANIZATION_SELECTION_REQUIRED" | "FORBIDDEN_ORGANIZATION" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadVolumeProcurement(requestedOrganizationId?: string): Promise<Result> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipResult = await client.from("organization_memberships").select("organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER"]).limit(100);
  if (membershipResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const memberships = z.array(member).max(100).safeParse(membershipResult.data);
  if (!memberships.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const context = resolveClientOrganizationContext(memberships.data, requestedOrganizationId);
  if (context.status === "error") return context;
  const organization = context.membership;
  const [poolsResult, reservationsResult] = await Promise.all([
    client.from("service_inventory_pools").select("id,agreement_id,agreement_version_id,contracted_units::text,available_units::text,reserved_units::text,committed_units::text,consumed_units::text,released_units::text,status,window_end,row_version::text").in("status", ["ACTIVE", "LOW_STOCK", "EXHAUSTED"]).order("window_end").limit(50),
    client.from("service_reservations").select("id,pool_id,client_organization_id,benefit_reference,reserved_units::text,consumed_units::text,released_units::text,status,expires_at").eq("client_organization_id", organization.organization_id).order("created_at", { ascending: false }).limit(100),
  ]);
  if (poolsResult.error || reservationsResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const pools = z.array(pool).safeParse(poolsResult.data), reservations = z.array(reservation).safeParse(reservationsResult.data);
  if (!pools.success || !reservations.success) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", dashboard: {
    organizationId: organization.organization_id,
    organizationName: organization.organizations.display_name,
    capabilities: { canReserve: true, canAllocate: false, canConsume: true },
    pools: pools.data.map((item) => ({ id: item.id, agreementId: item.agreement_id, agreementVersionId: item.agreement_version_id, contractedUnits: item.contracted_units, availableUnits: item.available_units, reservedUnits: item.reserved_units, committedUnits: item.committed_units, consumedUnits: item.consumed_units, releasedUnits: item.released_units, status: item.status, windowEnd: item.window_end, rowVersion: item.row_version })),
    reservations: reservations.data.map((item) => ({ id: item.id, poolId: item.pool_id, clientOrganizationId: item.client_organization_id, benefitReference: item.benefit_reference, reservedUnits: item.reserved_units, consumedUnits: item.consumed_units, releasedUnits: item.released_units, status: item.status, expiresAt: item.expires_at })),
    allocations: [], commitments: [],
  } };
}
