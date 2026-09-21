import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { uuidSchema } from "@/modules/client/data/rfq/model";
import { serviceCodeFromNeedSnapshot } from "@/modules/public/data/need-intent/model";

const serviceCodeSchema = z.string().regex(/^[A-Z][A-Z0-9_-]{1,79}$/u);
const intakeSchema = z.object({
  id: uuidSchema,
  organization_id: uuidSchema,
  need_text: z.string().min(10),
  location_text: z.string(),
  timing_text: z.string(),
  constraints_text: z.string(),
  locale: z.enum(["fr", "ar"]),
}).strict();
const conversionSchema = z.object({
  intake_id: uuidSchema,
  organization_id: uuidSchema,
  service_request_id: uuidSchema,
  service_code: z.string(),
}).strict();
const serviceSchema = z.object({
  id: uuidSchema,
  library_id: uuidSchema,
  code: z.string(),
  current_published_version_id: uuidSchema,
  status: z.literal("PUBLISHED"),
}).strict();
const serviceVersionSchema = z.object({
  id: uuidSchema,
  service_id: uuidSchema,
  library_id: uuidSchema,
  status: z.literal("PUBLISHED"),
  name_fr: z.string(),
  name_ar: z.string(),
}).strict();
const createdSchema = z.object({ request_id: uuidSchema, status: z.string() });

export type NeedRequestContext = {
  intakeId: string;
  serviceCode: string;
  organizationId: string;
  serviceNameFr: string;
  serviceNameAr: string;
  titleFr: string;
  titleAr: string;
  description: string;
  location: string;
  regionCode: string;
  existingRequestId: string | null;
};

export function regionCodeFromLocation(text: string): string {
  const value = text.trim().toUpperCase();
  return /^[A-Z]{2}-[A-Z0-9_-]{1,37}$/u.test(value) ? value : "";
}

export async function createRequestFromNeed(input: {
  intakeId: string;
  serviceCode: string;
  description: string;
  urgency: "LOW" | "NORMAL" | "HIGH" | "CRITICAL";
  desiredDate: string | null;
  budgetMinor: string | null;
  currency: "MAD";
  regionCode: string;
  siteId: string | null;
  changeReason: string;
  correlationId: string;
}): Promise<{ requestId: string; status: string } | { forbidden: true } | null> {
  const client = await getSupabaseServerClient();
  const result = await client.rpc("create_service_request_from_need_intake", {
    p_intake_id: input.intakeId,
    p_service_code: input.serviceCode,
    p_payload: {
      description: input.description,
      urgency: input.urgency,
      desired_date: input.desiredDate,
      budget_minor: input.budgetMinor,
      currency_code: input.currency,
      region_code: input.regionCode,
      site_id: input.siteId,
    },
    p_change_reason: input.changeReason,
    p_correlation_id: input.correlationId,
  });
  const parsed = createdSchema.safeParse(result.data);
  return result.error || !parsed.success ? (result.error?.code === "42501" ? { forbidden: true } : null) : { requestId: parsed.data.request_id, status: parsed.data.status };
}

export async function loadNeedRequestContext(
  intakeId: string,
  serviceCode?: string,
  organizationId?: string,
): Promise<NeedRequestContext | null> {
  if (!uuidSchema.safeParse(intakeId).success) return null;
  if (organizationId && !uuidSchema.safeParse(organizationId).success) return null;
  const client = await getSupabaseServerClient();
  let intakeQuery = client
    .from("public_need_intakes")
    .select("id,organization_id,need_text,location_text,timing_text,constraints_text,locale")
    .eq("id", intakeId);
  if (organizationId) intakeQuery = intakeQuery.eq("organization_id", organizationId);
  const intakeResult = await intakeQuery.maybeSingle();
  const intake = intakeSchema.safeParse(intakeResult.data);
  if (intakeResult.error || !intake.success) return null;

  const resolvedCode = serviceCodeSchema.safeParse(serviceCode).success
    ? serviceCode
    : serviceCodeFromNeedSnapshot(intake.data.constraints_text);
  if (!resolvedCode || !serviceCodeSchema.safeParse(resolvedCode).success) return null;

  const [conversionResult, serviceResult] = await Promise.all([
    client
      .from("public_need_intake_conversions")
      .select("intake_id,organization_id,service_request_id,service_code")
      .eq("intake_id", intake.data.id)
      .maybeSingle(),
    client
      .from("catalog_services")
      .select("id,library_id,code,current_published_version_id,status")
      .eq("code", resolvedCode)
      .eq("status", "PUBLISHED")
      .maybeSingle(),
  ]);
  const conversion = conversionResult.data ? conversionSchema.safeParse(conversionResult.data) : null;
  if (conversionResult.error) return null;
  if (conversion?.success && conversion.data.service_code !== resolvedCode) return null;

  const service = serviceSchema.safeParse(serviceResult.data);
  if (serviceResult.error || !service.success) return null;

  const versionResult = await client
    .from("catalog_service_versions")
    .select("id,service_id,library_id,status,name_fr,name_ar")
    .eq("id", service.data.current_published_version_id)
    .eq("service_id", service.data.id)
    .eq("library_id", service.data.library_id)
    .eq("status", "PUBLISHED")
    .maybeSingle();
  const version = serviceVersionSchema.safeParse(versionResult.data);
  if (versionResult.error || !version.success) return null;

  return {
    intakeId: intake.data.id,
    serviceCode: resolvedCode,
    organizationId: intake.data.organization_id,
    serviceNameFr: version.data.name_fr,
    serviceNameAr: version.data.name_ar,
    titleFr: version.data.name_fr,
    titleAr: version.data.name_ar,
    description: intake.data.need_text,
    location: intake.data.location_text,
    regionCode: regionCodeFromLocation(intake.data.location_text),
    existingRequestId: conversion?.success ? conversion.data.service_request_id : null,
  };
}
