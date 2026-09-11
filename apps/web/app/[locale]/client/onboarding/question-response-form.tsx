"use client";

import { useActionState, useId } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Locale } from "@/lib/i18n/locale";
import { respondClientComplianceQuestion, type QuestionResponseActionState } from "./actions";
import { formatVersionMessage, type ClientOnboardingMessages } from "./messages";

const initialState: QuestionResponseActionState = { status: "idle" };

export function ClientQuestionResponseForm({ questionId, locale, idempotencyKey, messages }: {
  questionId: string;
  locale: Locale;
  idempotencyKey: string;
  messages: ClientOnboardingMessages;
}) {
  const [state, action, pending] = useActionState(respondClientComplianceQuestion, initialState);
  const prefix = useId();
  const statusId = `${prefix}-status`;
  const error = state.status === "error"
    ? state.reason === "VALIDATION" ? messages.questionErrors.validation
      : state.reason === "UNAUTHENTICATED" ? messages.questionErrors.unauthenticated
        : messages.questionErrors.generic
    : null;
  if (state.status === "success") {
    return <p role="status" aria-live="polite" className="rounded-lg border border-primary/30 bg-primary/5 p-3 text-sm text-primary">{formatVersionMessage(messages.questionAnswered, state.version)}</p>;
  }
  return (
    <form action={action} className="space-y-3" aria-describedby={statusId} noValidate>
      <input type="hidden" name="questionId" value={questionId} />
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <Label htmlFor={`${prefix}-response`}>{messages.questionResponse}</Label>
      <Textarea id={`${prefix}-response`} name="responseText" required minLength={3} maxLength={4000} rows={5} aria-invalid={state.status === "error" && state.reason === "VALIDATION"} />
      <Button type="submit" disabled={pending} className="min-h-11 w-full sm:w-auto">{pending ? messages.questionResponding : messages.questionRespond}</Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>{error ?? ""}</p>
    </form>
  );
}
