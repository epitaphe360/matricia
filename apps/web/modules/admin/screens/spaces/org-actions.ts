"use server";

import { createHash, randomUUID } from "node:crypto";
import { requestAdminAction, type AdminActionState } from "@/modules/admin/screens/command-center/actions";

export type { AdminActionState };

function value(form: FormData, key: string) {
  return String(form.get(key) ?? "").trim();
}

export async function requestOrganizationMutation(previous: AdminActionState, form: FormData): Promise<AdminActionState> {
  const intent = value(form, "intent") || "CHANGE_CONFIGURATION";
  const summary = {
    intent,
    displayName: value(form, "displayName"),
    legalName: value(form, "legalName"),
    acronym: value(form, "acronym"),
    description: value(form, "description"),
    address: value(form, "address"),
    city: value(form, "city"),
    postalCode: value(form, "postalCode"),
    country: value(form, "country"),
    phone: value(form, "phone"),
    email: value(form, "email"),
    website: value(form, "website"),
    legalForm: value(form, "legalForm"),
    ice: value(form, "ice"),
    status: value(form, "status"),
    note: value(form, "note"),
    kind: value(form, "kind"),
  };
  const canonical = JSON.stringify(summary);
  form.set("redactedSummary", canonical);
  form.set("requestPayloadHash", createHash("sha256").update(canonical).digest("hex"));
  form.set("actionType", intent === "SUSPEND_ENTITY" || intent === "RESTRICT_ENTITY" ? intent : intent === "CREATE_ORGANIZATION" ? "CHANGE_CONFIGURATION" : "CHANGE_CONFIGURATION");
  form.set("resourceType", "ORGANIZATION");
  if (!value(form, "resourceId")) form.set("resourceId", value(form, "organizationId") || randomUUID());
  if (!value(form, "idempotencyKey")) form.set("idempotencyKey", randomUUID());
  if (!value(form, "targetEnvironment")) form.set("targetEnvironment", process.env.APP_ENV === "production" ? "STAGING" : "DEVELOPMENT");
  return requestAdminAction(previous, form);
}
