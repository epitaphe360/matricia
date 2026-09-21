"use client";

import { useActionState, useId, useState } from "react";
import { actorCopy } from "@/modules/admin/data/spaces/actors-copy";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import { decideClientCompliance, type ComplianceDecision, type ComplianceDecisionState } from "@/modules/admin/screens/conformite-clients/actions";
import { getComplianceMessages } from "@/modules/admin/screens/conformite-clients/messages";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const idle: ComplianceDecisionState = { status: "idle" };

export function ComplianceFigmaForm({
  complianceCaseId,
  locale,
  idempotencyKey,
}: {
  complianceCaseId: string;
  locale: Locale;
  idempotencyKey: string;
}) {
  const a = actorCopy(locale);
  const c = adminCopy(locale);
  const messages = getComplianceMessages(locale);
  const [state, action, pending] = useActionState(decideClientCompliance, idle);
  const [choice, setChoice] = useState<"VERIFIED" | "VERIFIED_COND" | "REJECTED">("VERIFIED");
  const statusId = useId();
  const decision: ComplianceDecision = choice === "REJECTED" ? "REJECTED" : "VERIFIED";
  const reasonRequired = choice !== "VERIFIED";

  if (state.status === "success") {
    return <p className="admin-banner" data-tone="ok" role="status">{messages.successes[state.decision]}</p>;
  }
  const error = state.status === "error"
    ? state.reason === "VALIDATION" ? messages.errors.validation
      : state.reason === "MFA_REQUIRED" ? messages.errors.mfa
        : state.reason === "FORBIDDEN" ? messages.errors.forbidden
          : messages.errors.generic
    : null;

  return (
    <form action={action} className="admin-form-grid">
      <input type="hidden" name="complianceCaseId" value={complianceCaseId} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="confirmed" value="yes" />
      <input type="hidden" name="decision" value={decision} />
      <fieldset className="admin-field">
        <legend>{a.decision} *</legend>
        <div className="admin-radio-row">
          <label><input type="radio" name="choice" checked={choice === "VERIFIED"} onChange={() => setChoice("VERIFIED")} /> {a.approveClient}</label>
          <label><input type="radio" name="choice" checked={choice === "VERIFIED_COND"} onChange={() => setChoice("VERIFIED_COND")} /> {a.approveCond}</label>
          <label><input type="radio" name="choice" checked={choice === "REJECTED"} onChange={() => setChoice("REJECTED")} /> {a.refuseClient}</label>
        </div>
      </fieldset>
      <div className="admin-field">
        <label htmlFor="figma-motif">{a.changeReason} *</label>
        <select id="figma-motif" name="motif" defaultValue="review">
          <option value="review">{messages.reason}</option>
        </select>
      </div>
      <div className="admin-field">
        <label htmlFor="figma-pieces">{a.heldPieces} *</label>
        <input id="figma-pieces" name="heldPieces" defaultValue={messages.evidence} />
      </div>
      <div className="admin-field" data-span>
        <label htmlFor="figma-reason">{a.justification} *</label>
        <textarea id="figma-reason" name="reasonPublic" required={reasonRequired} minLength={reasonRequired ? 3 : undefined} maxLength={1000} />
      </div>
      <div className="admin-field" data-span>
        <label htmlFor="figma-internal">{a.internalNote}</label>
        <textarea id="figma-internal" name="internalNote" maxLength={2000} />
      </div>
      <div className="admin-form-foot" data-span>
        <button type="submit" name="decision" value="QUESTION_REQUIRED" className="admin-danger-cta" disabled={pending}>{a.askComplement}</button>
        <button type="submit" className="admin-soft-cta" disabled={pending}>{c.saveDraft}</button>
        <button type="submit" className="admin-primary-cta" disabled={pending}>{pending ? messages.submitting : a.submitValidation}</button>
      </div>
      <p id={statusId} role={error ? "alert" : "status"} className={error ? "admin-error" : undefined}>{error ?? ""}</p>
    </form>
  );
}
