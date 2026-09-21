"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import { Label } from "@/modules/shared/ui/label";
import { Textarea } from "@/modules/shared/ui/textarea";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import {
  createClientComplianceQuestion,
  evaluateClientCompliance,
  reviewClientComplianceResponse,
  type ComplianceWorkflowState,
} from "./actions";
import type { ComplianceMessages } from "./messages";

const initialState: ComplianceWorkflowState = { status: "idle" };

function errorMessage(state: ComplianceWorkflowState, messages: ComplianceMessages): string | null {
  if (state.status !== "error") return null;
  if (state.reason === "VALIDATION") return messages.errors.validation;
  if (state.reason === "UNAUTHENTICATED") return messages.errors.unauthenticated;
  if (state.reason === "MFA_REQUIRED") return messages.errors.mfa;
  if (state.reason === "FORBIDDEN") return messages.errors.forbidden;
  return messages.errors.generic;
}

function WorkflowStatus({ state, messages, id }: {
  state: ComplianceWorkflowState;
  messages: ComplianceMessages;
  id: string;
}) {
  const error = errorMessage(state, messages);
  const success = state.status === "success" ? messages.workflowSuccesses[state.outcome] : null;
  return (
    <p
      id={id}
      role={error ? "alert" : "status"}
      aria-live="polite"
      className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}
    >
      {error ?? success ?? ""}
    </p>
  );
}

function HiddenFields({ locale, idempotencyKey }: { locale: Locale; idempotencyKey: string }) {
  return (
    <>
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
    </>
  );
}

export function EvaluateComplianceForm({ complianceCaseId, idempotencyKey, locale, messages }: {
  complianceCaseId: string;
  idempotencyKey: string;
  locale: Locale;
  messages: ComplianceMessages;
}) {
  const [state, action, pending] = useActionState(evaluateClientCompliance, initialState);
  const statusId = useId();
  return (
    <form action={action} className="space-y-3" aria-describedby={statusId}>
      <HiddenFields locale={locale} idempotencyKey={idempotencyKey} />
      <input type="hidden" name="complianceCaseId" value={complianceCaseId} />
      <p className="text-sm leading-6 text-muted-foreground">{messages.evaluateHint}</p>
      <label className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input type="checkbox" name="confirmed" value="yes" required className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.evaluateConfirm}</span>
      </label>
      <Button type="submit" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending}>
        {pending ? messages.evaluating : messages.evaluateSubmit}
      </Button>
      <WorkflowStatus state={state} messages={messages} id={statusId} />
    </form>
  );
}

export function CreateComplianceQuestionForm({ anomalyId, idempotencyKey, requestAnchor, locale, messages }: {
  anomalyId: string;
  idempotencyKey: string;
  requestAnchor: string;
  locale: Locale;
  messages: ComplianceMessages;
}) {
  const [state, action, pending] = useActionState(createClientComplianceQuestion, initialState);
  const statusId = useId();
  const questionFrId = useId();
  const questionArId = useId();
  const documentId = useId();
  const dueId = useId();
  return (
    <form action={action} className="mt-4 space-y-4 rounded-lg border bg-background p-4" aria-describedby={statusId}>
      <HiddenFields locale={locale} idempotencyKey={idempotencyKey} />
      <input type="hidden" name="anomalyId" value={anomalyId} />
      <input type="hidden" name="requestAnchor" value={requestAnchor} />
      <div className="space-y-2">
        <Label htmlFor={questionFrId}>{messages.questionFr}</Label>
        <Textarea id={questionFrId} name="questionFr" dir="ltr" lang="fr" minLength={3} maxLength={1000} required rows={3} />
      </div>
      <div className="space-y-2">
        <Label htmlFor={questionArId}>{messages.questionAr}</Label>
        <Textarea id={questionArId} name="questionAr" dir="rtl" lang="ar" minLength={3} maxLength={1000} required rows={3} />
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor={documentId}>{messages.expectedDocument}</Label>
          <select id={documentId} name="expectedDocumentType" defaultValue="NONE" className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm">
            <option value="NONE">{messages.noExpectedDocument}</option>
            <option value="REGISTRATION_DOCUMENT">{messages.evidenceTypes.REGISTRATION_DOCUMENT}</option>
            <option value="REPRESENTATIVE_AUTHORITY">{messages.evidenceTypes.REPRESENTATIVE_AUTHORITY}</option>
            <option value="TAX_DOCUMENT">{messages.evidenceTypes.TAX_DOCUMENT}</option>
          </select>
        </div>
        <div className="space-y-2">
          <Label htmlFor={dueId}>{messages.dueIn}</Label>
          <select id={dueId} name="dueDays" defaultValue="7" className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm">
            {[1, 3, 5, 7, 14, 30].map((days) => <option key={days} value={days}>{days} {messages.days}</option>)}
          </select>
        </div>
      </div>
      <label className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input type="checkbox" name="confirmed" value="yes" required className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.questionConfirm}</span>
      </label>
      <Button type="submit" className="min-h-11 w-full sm:w-auto" disabled={pending}>
        {pending ? messages.creatingQuestion : messages.createQuestion}
      </Button>
      <WorkflowStatus state={state} messages={messages} id={statusId} />
    </form>
  );
}

export function ReviewComplianceResponseForm({ questionId, idempotencyKey, locale, messages }: {
  questionId: string;
  idempotencyKey: string;
  locale: Locale;
  messages: ComplianceMessages;
}) {
  const [state, action, pending] = useActionState(reviewClientComplianceResponse, initialState);
  const statusId = useId();
  return (
    <form action={action} className="mt-4 space-y-3" aria-describedby={statusId}>
      <HiddenFields locale={locale} idempotencyKey={idempotencyKey} />
      <input type="hidden" name="questionId" value={questionId} />
      <label className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input type="checkbox" name="confirmed" value="yes" required className="mt-0.5 size-5 shrink-0 accent-primary" />
        <span>{messages.responseConfirm}</span>
      </label>
      <div className="flex flex-col gap-2 sm:flex-row">
        <Button type="submit" name="accepted" value="yes" className="min-h-11" disabled={pending}>{pending ? messages.reviewingResponse : messages.acceptResponse}</Button>
        <Button type="submit" name="accepted" value="no" variant="destructive" className="min-h-11" disabled={pending}>{pending ? messages.reviewingResponse : messages.rejectResponse}</Button>
      </div>
      <WorkflowStatus state={state} messages={messages} id={statusId} />
    </form>
  );
}
