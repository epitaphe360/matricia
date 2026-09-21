"use client";

import { useActionState } from "react";
import { requestClientRole, type ModeClientActionState } from "./actions";
import { Button } from "@/modules/shared/ui/button";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const idle: ModeClientActionState = { status: "idle" };

export function ActivateClientRoleForm({
  locale,
  organizationId,
  idempotencyKey,
}: {
  locale: Locale;
  organizationId: string;
  idempotencyKey: string;
}) {
  const [state, action, pending] = useActionState(requestClientRole, idle);
  const ar = locale === "ar";
  const label = state.status === "success"
    ? (state.outcome === "ROLE_REQUEST_ALREADY_PENDING" ? (ar ? "الطلب معلّق مسبقاً." : "Une demande est déjà en attente.") : (ar ? "تم تسجيل طلب الدور." : "La demande de rôle Client est enregistrée."))
    : state.status === "error"
      ? (state.reason === "VALIDATION" ? (ar ? "تحققوا من المؤسسة." : "Vérifiez l’organisation.") : ar ? "تعذر تسجيل الطلب." : "La demande n’a pas pu être enregistrée.")
      : "";
  return (
    <form action={action} className="grid gap-3">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="organizationId" value={organizationId} />
      <input type="hidden" name="requestedRoleCode" value="CLIENT_OWNER" />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <p className="client-access-note">{ar ? "نفس جواز المؤسسة. موافقة مركزية لازمة لإضافة دور مالك عميل." : "Même passeport organisation. L’ajout du rôle Client propriétaire exige une approbation centrale."}</p>
      <Button disabled={pending} className="min-h-11">{pending ? (ar ? "جارٍ الإرسال…" : "Envoi…") : (ar ? "طلب تفعيل وضع العميل" : "Demander le Mode Client")}</Button>
      {label ? <p role={state.status === "error" ? "alert" : "status"}>{label}</p> : null}
    </form>
  );
}
