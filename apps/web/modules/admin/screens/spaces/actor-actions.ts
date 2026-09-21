"use server";

import { createHash, randomUUID } from "node:crypto";
import { createInvitation, type InvitationActionState } from "@/app/[locale]/invitations/actions";
import { requestAdminAction, type AdminActionState } from "@/modules/admin/screens/command-center/actions";
import { revalidatePath } from "next/cache";

export type { AdminActionState };
export type ActorInviteState = InvitationActionState | AdminActionState;

function value(form: FormData, key: string) {
  return String(form.get(key) ?? "").trim();
}

function prepareFourEyes(form: FormData, resourceType: string) {
  const intent = value(form, "intent") || "CHANGE_CONFIGURATION";
  const summary = {
    intent,
    invitedEmail: value(form, "invitedEmail"),
    organizationId: value(form, "organizationId"),
    roleCode: value(form, "roleCode") || value(form, "roleCodes"),
    perimeter: value(form, "perimeter"),
    inviteLocale: value(form, "inviteLocale"),
    message: value(form, "message"),
    userId: value(form, "userId"),
    currentRole: value(form, "currentRole"),
    newRole: value(form, "newRole"),
    capabilities: form.getAll("capabilities").map(String),
    scope: value(form, "scope"),
    entities: value(form, "entities"),
    note: value(form, "note"),
  };
  const canonical = JSON.stringify(summary);
  form.set("redactedSummary", canonical);
  form.set("requestPayloadHash", createHash("sha256").update(canonical).digest("hex"));
  form.set("actionType", intent === "SUSPEND_ENTITY" || intent === "RESTRICT_ENTITY" ? intent : "CHANGE_CONFIGURATION");
  form.set("resourceType", resourceType);
  if (!value(form, "resourceId")) form.set("resourceId", value(form, "userId") || value(form, "invitationId") || value(form, "organizationId") || randomUUID());
  if (!value(form, "idempotencyKey")) form.set("idempotencyKey", randomUUID());
  if (!value(form, "targetEnvironment")) form.set("targetEnvironment", process.env.APP_ENV === "production" ? "STAGING" : "DEVELOPMENT");
  if (!value(form, "reason")) form.set("reason", value(form, "note") || "Demande d’accès administrateur soumise au contrôle à quatre yeux.");
}

export async function requestActorMutation(previous: AdminActionState, form: FormData): Promise<AdminActionState> {
  prepareFourEyes(form, value(form, "resourceType") || "MEMBERSHIP");
  const result = await requestAdminAction(previous, form);
  const locale = value(form, "locale") || "fr";
  revalidatePath(`/${locale}/administration/utilisateurs`);
  revalidatePath(`/${locale}/administration/clients`);
  return result;
}

export async function submitActorInvitation(previous: ActorInviteState, form: FormData): Promise<ActorInviteState> {
  const canInviteDirectly = value(form, "canInvite") === "yes";
  if (canInviteDirectly && value(form, "intent") !== "INVITE_DRAFT") {
    if (!form.get("roleCodes") && value(form, "roleCode")) form.set("roleCodes", value(form, "roleCode"));
    if (!value(form, "expiryDays")) form.set("expiryDays", "7");
    const invited = await createInvitation({ status: "idle" }, form);
    if (invited.status === "success") {
      revalidatePath(`/${value(form, "locale") || "fr"}/administration/utilisateurs`);
      return invited;
    }
    if (invited.status === "error" && invited.reason === "VALIDATION") return invited;
  }
  prepareFourEyes(form, "INVITATION");
  return requestAdminAction({ status: "idle" }, form);
}
