"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createServerDiagnosticsRepository } from "@/modules/shared/lib/diagnostics-opportunities/server-repository";
import { uuid } from "@/modules/shared/lib/diagnostics-opportunities/model";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

export type State = {
  status: "idle" | "success" | "error";
  reason?: "VALIDATION" | "COMMAND" | "NO_SUBMITTED_ASSESSMENT" | "ANALYSIS_SCOPE_REQUIRED";
};
export const idle: State = { status: "idle" };
const base = z.object({ locale: z.enum(["fr", "ar"]), idempotencyKey: uuid });
function values(f: FormData) { return Object.fromEntries(f.entries()); }

export async function completeLatestAction(_: State, f: FormData): Promise<State> {
  const parsed = base.extend({ organizationId: uuid, confirmSnapshot: z.literal("CONFIRMED") }).safeParse(values(f));
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };

  const repository = await createServerDiagnosticsRepository();
  const dashboard = await repository.list();
  if (dashboard.status === "error") return { status: "error", reason: "COMMAND" };
  const latestSession = dashboard.value.sessions.find((session) => session.organizationId === parsed.data.organizationId);
  if (!latestSession) return { status: "error", reason: "NO_SUBMITTED_ASSESSMENT" };

  // The published service is resolved and revalidated server-side in the same
  // library as the submitted assessment. No technical identifier is trusted
  // from the browser.
  const client = await getSupabaseServerClient();
  const services = await client
    .from("catalog_services")
    .select("id")
    .eq("library_id", latestSession.libraryId)
    .eq("status", "PUBLISHED")
    .not("current_published_version_id", "is", null)
    .order("code", { ascending: true })
    .limit(2);
  // A service can only be inferred when the published scope is unambiguous.
  // Choosing the first of several services would fabricate a recommendation.
  if (services.error || services.data?.length !== 1) return { status: "error", reason: "ANALYSIS_SCOPE_REQUIRED" };

  const result = await repository.complete({
    sessionId: latestSession.id,
    serviceId: services.data[0].id,
    idempotencyKey: parsed.data.idempotencyKey,
    correlationId: randomUUID(),
  });
  if (result.status === "error") return { status: "error", reason: "COMMAND" };
  revalidatePath(`/${parsed.data.locale}/client/diagnostics`);
  return { status: "success" };
}
export async function completeAction(_:State,f:FormData):Promise<State>{const p=base.extend({sessionId:uuid,serviceId:uuid,confirmSnapshot:z.literal("CONFIRMED")}).safeParse(values(f));if(!p.success)return{status:"error",reason:"VALIDATION"};const r=await(await createServerDiagnosticsRepository()).complete({sessionId:p.data.sessionId,serviceId:p.data.serviceId,idempotencyKey:p.data.idempotencyKey,correlationId:randomUUID()});if(r.status==="error")return{status:"error",reason:"COMMAND"};revalidatePath(`/${p.data.locale}/client/diagnostics`);return{status:"success"}}
export async function opportunityAction(_:State,f:FormData):Promise<State>{const p=base.extend({runId:uuid,opportunityId:uuid,action:z.enum(["ACCEPT","DEFER","REQUEST_RFQ","CLOSE"]),deferredUntil:z.union([z.string().regex(/^\d{4}-\d{2}-\d{2}$/u),z.literal("")]),rowVersion:z.coerce.number().int().positive()}).safeParse(values(f));if(!p.success||(p.data.action==="DEFER"&&!p.data.deferredUntil))return{status:"error",reason:"VALIDATION"};const r=await(await createServerDiagnosticsRepository()).transition({opportunityId:p.data.opportunityId,action:p.data.action,deferredUntil:p.data.deferredUntil?`${p.data.deferredUntil}T23:59:59Z`:null,rowVersion:p.data.rowVersion,idempotencyKey:p.data.idempotencyKey,correlationId:randomUUID()});if(r.status==="error")return{status:"error",reason:"COMMAND"};revalidatePath(`/${p.data.locale}/client/diagnostics/${p.data.runId}`);return{status:"success"}}
