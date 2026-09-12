"use server";

import { z } from "zod";
import { isLocale } from "@/lib/i18n/locale";
import { providerCapacityInputSchema, providerDocumentInputSchema, providerProfileInputSchema, providerServiceInputSchema } from "@/lib/provider-qualification/model";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export type ProviderActionState = { status: "idle" } | { status: "success"; outcome: string } | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "CONFLICT" | "FAILED" };
const outcomeSchema = z.object({ outcome: z.string().min(3), command_id: z.string().uuid() }).passthrough();
const text = (data: FormData, key: string) => String(data.get(key) ?? "");
function failure(error: { code?: string; message?: string } | null): ProviderActionState {
  if (error?.code === "42501") return { status: "error", reason: "FORBIDDEN" };
  if (error?.code === "40001" || error?.code === "23505" || error?.message?.includes("IDEMPOTENCY")) return { status: "error", reason: "CONFLICT" };
  return { status: "error", reason: "FAILED" };
}
async function rpc(name: string, args: Record<string, unknown>): Promise<ProviderActionState> {
  const client = await getSupabaseServerClient(); const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const result = await client.rpc(name, args); if (result.error) return failure(result.error);
  const parsed = outcomeSchema.safeParse(result.data); return parsed.success ? { status: "success", outcome: parsed.data.outcome } : { status: "error", reason: "FAILED" };
}
export async function submitProviderProfile(_: ProviderActionState, data: FormData): Promise<ProviderActionState> {
  if (!isLocale(text(data,"locale"))) return { status:"error",reason:"VALIDATION" };
  const parsed=providerProfileInputSchema.safeParse({organizationId:text(data,"organizationId"),expectedRowVersion:text(data,"expectedRowVersion"),activitySummary:text(data,"activitySummary"),teamSize:text(data,"teamSize"),yearsExperience:text(data,"yearsExperience"),accountingContactEmail:text(data,"accountingContactEmail"),secondarySubcontractingAllowed:data.get("secondarySubcontractingAllowed")==="yes",idempotencyKey:text(data,"idempotencyKey")});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};const v=parsed.data;
  return rpc("submit_provider_profile",{p_provider_organization_id:v.organizationId,p_profile:{activity_summary:v.activitySummary,team_size:v.teamSize,years_experience:v.yearsExperience,accounting_contact_email:v.accountingContactEmail,secondary_subcontracting_allowed:v.secondarySubcontractingAllowed},p_expected_row_version:v.expectedRowVersion,p_idempotency_key:v.idempotencyKey});
}
export async function requestProviderService(_: ProviderActionState,data:FormData):Promise<ProviderActionState>{
  if(!isLocale(text(data,"locale")))return{status:"error",reason:"VALIDATION"};const parsed=providerServiceInputSchema.safeParse({organizationId:text(data,"organizationId"),serviceId:text(data,"serviceId"),idempotencyKey:text(data,"idempotencyKey")});if(!parsed.success)return{status:"error",reason:"VALIDATION"};return rpc("request_provider_service",{p_provider_organization_id:parsed.data.organizationId,p_service_id:parsed.data.serviceId,p_idempotency_key:parsed.data.idempotencyKey});
}
export async function declareProviderCapacity(_:ProviderActionState,data:FormData):Promise<ProviderActionState>{
  if(!isLocale(text(data,"locale")))return{status:"error",reason:"VALIDATION"};const status=text(data,"capacityStatus");const unitsRaw=text(data,"availableUnits");const parsed=providerCapacityInputSchema.safeParse({organizationId:text(data,"organizationId"),serviceId:text(data,"serviceId")||null,capacityStatus:status,availableUnits:status==="PAUSED"?null:Number(unitsRaw),leadTimeDays:Number(text(data,"leadTimeDays")),reason:text(data,"reason"),idempotencyKey:text(data,"idempotencyKey")});if(!parsed.success)return{status:"error",reason:"VALIDATION"};const v=parsed.data;return rpc("declare_provider_capacity",{p_provider_organization_id:v.organizationId,p_service_id:v.serviceId,p_capacity_status:v.capacityStatus,p_available_units:v.availableUnits,p_lead_time_days:v.leadTimeDays,p_reason:v.reason,p_idempotency_key:v.idempotencyKey});
}
export async function recordProviderDocument(_:ProviderActionState,data:FormData):Promise<ProviderActionState>{
  if(!isLocale(text(data,"locale")))return{status:"error",reason:"VALIDATION"};const parsed=providerDocumentInputSchema.safeParse({organizationId:text(data,"organizationId"),documentKind:text(data,"documentKind"),code:text(data,"code").toUpperCase(),issuerName:text(data,"issuerName"),referenceNumber:text(data,"referenceNumber"),issuedOn:text(data,"issuedOn"),expiresOn:text(data,"expiresOn"),storageObjectPath:text(data,"storageObjectPath"),contentHash:text(data,"contentHash"),providerServiceIds:data.getAll("providerServiceIds").map(String),changeReason:text(data,"changeReason"),idempotencyKey:text(data,"idempotencyKey")});if(!parsed.success)return{status:"error",reason:"VALIDATION"};const v=parsed.data;return rpc("record_provider_document_version",{p_provider_organization_id:v.organizationId,p_document_kind:v.documentKind,p_code:v.code,p_document:{issuer_name:v.issuerName,reference_number:v.referenceNumber,issued_on:v.issuedOn,expires_on:v.expiresOn,storage_object_path:v.storageObjectPath,content_hash:v.contentHash,metadata:{}},p_provider_service_ids:v.providerServiceIds,p_change_reason:v.changeReason,p_idempotency_key:v.idempotencyKey});
}
