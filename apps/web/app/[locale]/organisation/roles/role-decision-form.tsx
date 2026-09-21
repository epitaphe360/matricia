"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { decideRoleRequest, type RoleDecisionActionState } from "./actions";
import type { RoleMessages } from "./messages";

const initialState: RoleDecisionActionState = { status: "idle" };

export function RoleDecisionForm({
  requestId,
  locale,
  decision,
  messages,
}: {
  requestId: string;
  locale: Locale;
  decision: "APPROVE" | "REJECT";
  messages: RoleMessages;
}) {
  const [state, action, pending] = useActionState(decideRoleRequest, initialState);
  const confirmationId = useId();
  const statusId = useId();
  const error = state.status === "error"
    ? state.reason === "VALIDATION" ? messages.decisionErrors.validation
      : state.reason === "UNAUTHENTICATED" ? messages.decisionErrors.unauthenticated
        : messages.decisionErrors.generic
    : null;
  return (
    <form action={action} className="space-y-3" aria-describedby={statusId}>
      <input type="hidden" name="requestId" value={requestId} />
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="decision" value={decision} />
      <label htmlFor={confirmationId} className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input id={confirmationId} type="checkbox" name="confirmed" value="yes" required className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.confirm}</span>
      </label>
      <Button type="submit" variant={decision === "APPROVE" ? "default" : "outline"} className="min-h-11 w-full sm:w-auto" disabled={pending}>
        {pending ? messages.deciding : decision === "APPROVE" ? messages.approve : messages.reject}
      </Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>
        {error ?? (state.status === "success" ? state.decision === "APPROVE" ? messages.approved : messages.rejected : "")}
      </p>
    </form>
  );
}
