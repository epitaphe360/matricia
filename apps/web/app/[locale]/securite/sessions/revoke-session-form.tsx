"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import { revokeMySession, type RevokeSessionState } from "./actions";

type Messages = {
  confirm: string;
  revoke: string;
  pending: string;
  revoked: string;
  errors: {
    validation: string;
    unauthenticated: string;
    current: string;
    generic: string;
  };
};

const initialState: RevokeSessionState = { status: "idle" };

export function RevokeSessionForm({ sessionId, locale, messages }: { sessionId: string; locale: "fr" | "ar"; messages: Messages }) {
  const [state, action, pending] = useActionState(revokeMySession, initialState);
  const confirmationId = useId();
  const statusId = useId();
  const error = state.status === "error"
    ? state.reason === "VALIDATION"
      ? messages.errors.validation
      : state.reason === "UNAUTHENTICATED"
        ? messages.errors.unauthenticated
        : state.reason === "CURRENT_SESSION"
          ? messages.errors.current
          : messages.errors.generic
    : null;

  return (
    <form action={action} className="space-y-3" aria-describedby={statusId}>
      <input type="hidden" name="sessionId" value={sessionId} />
      <input type="hidden" name="locale" value={locale} />
      <label htmlFor={confirmationId} className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-muted/40 p-3 text-sm leading-5">
        <input
          id={confirmationId}
          name="confirmed"
          value="yes"
          type="checkbox"
          required
          className="mt-0.5 size-5 shrink-0 accent-primary"
        />
        <span>{messages.confirm}</span>
      </label>
      <Button type="submit" variant="destructive" className="min-h-11 w-full sm:w-auto" disabled={pending} aria-describedby={statusId}>
        {pending ? messages.pending : messages.revoke}
      </Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "text-sm text-destructive" : "text-sm text-primary"}>
        {error ?? (state.status === "success" ? messages.revoked : "")}
      </p>
    </form>
  );
}
