import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { ficheSchema, supervisionSchema, type AdminOrganizationFiche, type AdminSupervisionDashboard, type AdminSupervisionResult } from "./types";
import { supervisionChartSeries } from "./series";

export type { AdminOrganizationFiche, AdminSupervisionDashboard, AdminSupervisionResult };
export { supervisionChartSeries };

const uuid = z.string().uuid();

export async function loadAdminSupervisionDashboard(limit = 50): Promise<AdminSupervisionResult<AdminSupervisionDashboard>> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const response = await client.rpc("list_admin_supervision_projection", { p_limit: limit });
  if (response.error) {
    return { status: "error", reason: response.error.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
  }
  const parsed = supervisionSchema.safeParse(response.data);
  return parsed.success ? { status: "success", value: parsed.data } : { status: "error", reason: "INVALID_RESPONSE" };
}

export async function loadAdminOrganizationFiche(organizationId: string): Promise<AdminSupervisionResult<AdminOrganizationFiche>> {
  const id = uuid.safeParse(organizationId);
  if (!id.success) return { status: "error", reason: "NOT_FOUND" };
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const response = await client.rpc("get_admin_organization_fiche", { p_organization_id: id.data });
  if (response.error) {
    if (response.error.code === "42501") return { status: "error", reason: "FORBIDDEN" };
    if (response.error.code === "P0002") return { status: "error", reason: "NOT_FOUND" };
    return { status: "error", reason: "UNAVAILABLE" };
  }
  const parsed = ficheSchema.safeParse(response.data);
  return parsed.success ? { status: "success", value: parsed.data } : { status: "error", reason: "INVALID_RESPONSE" };
}
