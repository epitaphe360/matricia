"use client";

import { useActionState, useId, useState } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Locale } from "@/lib/i18n/locale";
import { decideClientCompliance, type ComplianceDecision, type ComplianceDecisionState } from "./actions";
import type { ComplianceMessages } from "./messages";

const initialState: ComplianceDecisionState = { status: "idle" };
const decisions = ["VERIFIED", "QUESTION_REQUIRED", "REJECTED"] as const;

export function ComplianceDecisionForm({
  complianceCaseId,
  idempotencyKey,
  locale,
  messages,
}: {
  complianceCaseId: string;
  idempotencyKey: string;
  locale: Locale;
  messages: ComplianceMessages;
}) {
  const [state, action, pending] = useActionState(decideClientCompliance, initialState);
  const [decision, setDecision] = useState<ComplianceDecision>("VERIFIED");
  const statusId = useId();
  const reasonHintId = useId();
  const reasonRequired = decision === "QUESTION_REQUIRED" || decision === "REJECTED";
  const error = state.status === "error"
    ? state.reason === "VALIDATION" ? messages.errors.validation
      : state.reason === "UNAUTHENTICATED" ? messages.errors.unauthenticated
        : state.reason === "MFA_REQUIRED" ? messages.errors.mfa
          : state.reason === "FORBIDDEN" ? messages.errors.forbidden
            : messages.errors.generic
    : null;

  if (state.status === "success") {
    return <p role="status" tabIndex={-1} className="rounded-lg border border-primary/30 bg-primary/5 p-4 text-sm outline-none">{messages.successes[state.decision]}</p>;
  }
  return (
    <form action={action} className="space-y-4" aria-describedby={statusId} noValidate>
      <input type="hidden" name="complianceCaseId" value={complianceCaseId} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <input type="hidden" name="locale" value={locale} />
      <div className="space-y-2">
        <Label htmlFor={"decision-" + complianceCaseId}>{messages.decision}</Label>
        <select
          id={"decision-" + complianceCaseId}
          name="decision"
          value={decision}
          onChange={(event) => setDecision(event.target.value as ComplianceDecision)}
          className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
        >
          {decisions.map((value) => <option key={value} value={value}>{messages.decisions[value]}</option>)}
        </select>
      </div>
      <div className="space-y-2">
        <Label htmlFor={"reason-" + complianceCaseId}>{messages.reason}</Label>
        <Textarea
          id={"reason-" + complianceCaseId}
          name="reasonPublic"
          minLength={reasonRequired ? 3 : undefined}
          maxLength={1000}
          required={reasonRequired}
          rows={4}
          aria-describedby={reasonHintId}
        />
        <p id={reasonHintId} className="text-xs leading-5 text-muted-foreground">{messages.reasonHint}</p>
      </div>
      <label className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input type="checkbox" name="confirmed" value="yes" required className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.confirm}</span>
      </label>
      <Button type="submit" className="min-h-11 w-full sm:w-auto" disabled={pending}>{pending ? messages.submitting : messages.submit}</Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>{error ?? ""}</p>
    </form>
  );
}
