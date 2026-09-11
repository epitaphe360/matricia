"use client";

import { useActionState, useId } from "react";
import { Button } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { submitClientCompliance, type SubmitActionState } from "./actions";
import type { ClientOnboardingMessages } from "./messages";

const initialState: SubmitActionState = { status: "idle" };

export function SubmitComplianceForm({
  complianceCaseId,
  locale,
  idempotencyKey,
  messages,
}: {
  complianceCaseId: string;
  locale: Locale;
  idempotencyKey: string;
  messages: ClientOnboardingMessages;
}) {
  const [state, action, pending] = useActionState(submitClientCompliance, initialState);
  const statusId = useId();
  const error = state.status === "error"
    ? state.reason === "VALIDATION" ? messages.submitErrors.validation
      : state.reason === "UNAUTHENTICATED" ? messages.submitErrors.unauthenticated
        : messages.submitErrors.generic
    : null;
  if (state.status === "success") {
    return <p role="status" aria-live="polite" className="rounded-lg border border-primary/30 bg-primary/5 p-4 text-sm text-primary">{messages.submittedSuccess}</p>;
  }
  return (
    <form action={action} className="space-y-4" aria-describedby={statusId} noValidate>
      <input type="hidden" name="complianceCaseId" value={complianceCaseId} />
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <label className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-background p-3 text-sm leading-6 has-[:checked]:border-primary/60 has-[:checked]:bg-primary/5">
        <input name="confirmed" value="yes" type="checkbox" required aria-invalid={state.status === "error" && state.reason === "VALIDATION"} className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.submitConfirm}</span>
      </label>
      <Button type="submit" disabled={pending} className="min-h-11 w-full sm:w-auto">{pending ? messages.submitting : messages.submit}</Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>{error ?? ""}</p>
    </form>
  );
}
