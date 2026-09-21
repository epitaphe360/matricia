"use client";

import { useActionState, useId, useState, type FormEvent } from "react";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Label } from "@/modules/shared/ui/label";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import {
  uploadClientComplianceDocument,
  type DocumentUploadActionState,
} from "./actions";
import { formatVersionMessage, type ClientOnboardingMessages } from "./messages";

const initialState: DocumentUploadActionState = { status: "idle" };
const clientDocumentMaxBytes = 10_485_760;
const clientDocumentAccept = "application/pdf,image/jpeg,image/png";
const allowedExtensions: Record<string, string[]> = {
  "application/pdf": ["pdf"], "image/jpeg": ["jpg", "jpeg"], "image/png": ["png"],
};

export function ClientDocumentUploadForm({
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
  const [state, action, pending] = useActionState(uploadClientComplianceDocument, initialState);
  const [clientError, setClientError] = useState(false);
  const prefix = useId();
  const statusId = `${prefix}-status`;
  const validateFile = (event: FormEvent<HTMLFormElement>) => {
    const file = new FormData(event.currentTarget).get("file");
    const extension = file instanceof File ? file.name.split(".").pop()?.toLowerCase() ?? "" : "";
    const valid = file instanceof File && file.size > 0 && file.size <= clientDocumentMaxBytes
      && Boolean(allowedExtensions[file.type]?.includes(extension));
    setClientError(!valid);
    if (!valid) event.preventDefault();
  };
  const serverError = state.status === "error"
    ? state.reason === "VALIDATION" ? messages.documentErrors.validation
      : state.reason === "UNAUTHENTICATED" ? messages.documentErrors.unauthenticated
        : state.reason === "UPLOAD" ? messages.documentErrors.upload
          : messages.documentErrors.generic
    : null;
  const error = clientError ? messages.documentErrors.validation : serverError;

  if (state.status === "success") {
    return <p role="status" aria-live="polite" className="rounded-lg border border-primary/30 bg-primary/5 p-4 text-sm text-primary">{formatVersionMessage(messages.documentUploaded, state.version)}</p>;
  }
  return (
    <form action={action} onSubmit={validateFile} noValidate className="space-y-4" aria-describedby={statusId}>
      <input type="hidden" name="complianceCaseId" value={complianceCaseId} />
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-type`}>{messages.documentFields.type}</Label>
          <select id={`${prefix}-type`} name="documentType" required className="flex min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
            <option value="REGISTRATION_DOCUMENT">{messages.evidenceTypes.REGISTRATION_DOCUMENT}</option>
            <option value="REPRESENTATIVE_AUTHORITY">{messages.evidenceTypes.REPRESENTATIVE_AUTHORITY}</option>
            <option value="TAX_DOCUMENT">{messages.evidenceTypes.TAX_DOCUMENT}</option>
          </select>
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-number`}>{messages.documentFields.number}</Label>
          <Input id={`${prefix}-number`} name="documentNumber" required minLength={2} maxLength={120} />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-issuer`}>{messages.documentFields.issuer}</Label>
          <Input id={`${prefix}-issuer`} name="issuer" required minLength={2} maxLength={200} />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-issued`}>{messages.documentFields.issuedOn}</Label>
          <Input id={`${prefix}-issued`} name="issuedOn" type="date" required />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-expires`}>{messages.documentFields.expiresOn}</Label>
          <Input id={`${prefix}-expires`} name="expiresOn" type="date" />
        </div>
        <div className="space-y-2 sm:col-span-2">
          <Label htmlFor={`${prefix}-file`}>{messages.documentFields.file}</Label>
          <Input id={`${prefix}-file`} name="file" type="file" required accept={clientDocumentAccept} aria-invalid={Boolean(error)} onChange={() => setClientError(false)} className="min-h-11 file:me-3" />
          <p className="text-xs text-muted-foreground">{messages.documentUploadDescription}</p>
        </div>
      </div>
      <Button type="submit" disabled={pending} className="min-h-11 w-full sm:w-auto">{pending ? messages.documentUploading : messages.documentUpload}</Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>{error ?? ""}</p>
    </form>
  );
}
