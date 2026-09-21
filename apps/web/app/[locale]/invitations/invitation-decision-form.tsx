"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { acceptInvitation, declineInvitation, type InvitationActionState } from "./actions";
import type { InvitationMessages } from "./messages";

const initialState: InvitationActionState = { status: "idle" };

export function InvitationDecisionForm({
  invitationId,
  locale,
  mode,
  messages,
}: {
  invitationId: string;
  locale: Locale;
  mode: "accept" | "decline";
  messages: InvitationMessages;
}) {
  const [state, action, pending] = useActionState(mode === "accept" ? acceptInvitation : declineInvitation, initialState);
  const confirmationId = useId();
  const statusId = useId();
  const error = state.status === "error"
    ? state.reason === "VALIDATION"
      ? messages.decisionErrors.validation
      : state.reason === "UNAUTHENTICATED"
        ? messages.decisionErrors.unauthenticated
        : messages.decisionErrors.generic
    : null;

  return (
    <form action={action} className="space-y-3" aria-describedby={statusId}>
      <input type="hidden" name="invitationId" value={invitationId} />
      <input type="hidden" name="locale" value={locale} />
      <label htmlFor={confirmationId} className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input id={confirmationId} name="confirmed" value="yes" type="checkbox" required className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.decisionConfirm}</span>
      </label>
      <Button type="submit" variant={mode === "accept" ? "default" : "outline"} className="min-h-11 w-full sm:w-auto" disabled={pending}>
        {pending ? messages.deciding : mode === "accept" ? messages.accept : messages.decline}
      </Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>
        {error ?? (state.status === "success" ? mode === "accept" ? messages.accepted : messages.declined : "")}
      </p>
    </form>
  );
}
