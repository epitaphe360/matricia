import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { ficheSchema, supervisionSchema, type AdminOrganizationFiche, type AdminSupervisionDashboard, type AdminSupervisionResult } from "./types";
import { supervisionChartSeries } from "./series";

export type { AdminOrganizationFiche, AdminSupervisionDashboard, AdminSupervisionResult };
export { supervisionChartSeries };

const uuid = z.string().uuid();

export async function loadAdminSupervisionDashboard(limit = 50, consistent = false): Promise<AdminSupervisionResult<AdminSupervisionDashboard>> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  if(consistent){const response=await client.rpc("get_admin_supervision_snapshot_v1");if(response.error)return{status:"error",reason:response.error.code==="42501"?"FORBIDDEN":"UNAVAILABLE"};const parsed=supervisionSchema.safeParse(response.data);return parsed.success?{status:"success",value:parsed.data}:{status:"error",reason:"INVALID_RESPONSE"};}
  // Read each projection in bounded server pages; never compute totals from a
  // silently truncated 100-row snapshot. Detail readers remain separate.
  const pageSize = Math.min(500, Math.max(100, limit));
  let offset = 0;
  let result: AdminSupervisionDashboard | null = null;
  while (true) {
    const response = await client.rpc("list_admin_supervision_page_v1", { p_limit: pageSize, p_offset: offset });
    if (response.error) return { status: "error", reason: response.error.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
    const parsed = supervisionSchema.safeParse(response.data);
    if (!parsed.success) return { status: "error", reason: "INVALID_RESPONSE" };
    const page = parsed.data;
    if (!result) result = page;
    else {
      for (const [key, value] of Object.entries(page)) {
        if (Array.isArray(value)) (result as Record<string, unknown>)[key] = [...((result as Record<string, unknown>)[key] as unknown[] ?? []), ...value];
        else if (key === "work_enrichment") result.work_enrichment = { ...result.work_enrichment, ...page.work_enrichment };
      }
    }
    if (!Object.values(page).some((value) => Array.isArray(value) && value.length >= pageSize)) break;
    offset += pageSize;
  }
  return { status: "success", value: result };
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
