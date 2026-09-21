import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { adminBoxesDashboardSchema, type AdminBoxesDashboard, type AdminBoxesErrorReason, type AdminBoxesResult } from "./model";

function mapError(code?: string): AdminBoxesErrorReason {
  if (code === "42501") return "FORBIDDEN";
  if (code === "22023" || code === "P0002") return "INVALID_INPUT";
  if (["22000", "23505", "23514", "40001", "55000"].includes(code ?? "")) return "CONFLICT";
  return "UNAVAILABLE";
}

export async function loadAdminBoxesDashboard(): Promise<AdminBoxesResult<AdminBoxesDashboard>> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const response = await client.rpc("list_admin_boxes_dashboard", { p_limit: 100 });
  if (response.error) return { status: "error", reason: mapError(response.error.code) };
  const parsed = adminBoxesDashboardSchema.safeParse(response.data);
  return parsed.success ? { status: "success", value: parsed.data } : { status: "error", reason: "INVALID_RESPONSE" };
}

export async function callBoxesCommand(name: string, args: Record<string, unknown>): Promise<AdminBoxesResult<{ outcome: string }>> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const response = await client.rpc(name, args);
  if (response.error) return { status: "error", reason: mapError(response.error.code) };
  const outcome = response.data && typeof response.data === "object" && "outcome" in response.data ? String((response.data as { outcome: unknown }).outcome) : "";
  return outcome.length >= 3 ? { status: "success", value: { outcome } } : { status: "error", reason: "INVALID_RESPONSE" };
}
