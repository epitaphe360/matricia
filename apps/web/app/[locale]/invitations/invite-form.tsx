"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Label } from "@/modules/shared/ui/label";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { createInvitation, type InvitationActionState, type InvitationOrganization, type InvitationRole } from "./actions";
import type { InvitationMessages } from "./messages";

const initialState: InvitationActionState = { status: "idle" };
const roleGroups: InvitationRole[][] = [
  ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_ACCOUNTING", "CLIENT_MEMBER", "CLIENT_VIEWER"],
  ["PROVIDER_OWNER", "PROVIDER_MANAGER", "PROVIDER_SALES", "PROVIDER_TECHNICIAN", "PROVIDER_ACCOUNTING", "PROVIDER_VIEWER"],
  ["FRANCHISE_OWNER", "FRANCHISE_MANAGER", "FRANCHISE_EXPERT", "FRANCHISE_PROVIDER_MANAGER", "FRANCHISE_ACCOUNTING", "FRANCHISE_VIEWER"],
];

export function InviteForm({
  locale,
  organizations,
  messages,
  idempotencyKey,
}: {
  locale: Locale;
  organizations: InvitationOrganization[];
  messages: InvitationMessages;
  idempotencyKey: string;
}) {
  const [state, action, pending] = useActionState(createInvitation, initialState);
  const statusId = useId();
  const rolesHintId = useId();
  const error = state.status === "error"
    ? state.reason === "VALIDATION"
      ? messages.createErrors.validation
      : state.reason === "UNAUTHENTICATED"
        ? messages.createErrors.unauthenticated
        : messages.createErrors.generic
    : null;

  if (organizations.length === 0) {
    return <p className="rounded-lg border bg-muted/40 p-4 text-sm text-muted-foreground">{messages.noEligibleOrganization}</p>;
  }
  if (state.status === "success") {
    return (
      <div role="status" className="space-y-4 rounded-lg border border-primary/30 bg-primary/5 p-4">
        <p className="text-sm text-primary">{messages.sent}</p>
        <Button type="button" variant="outline" className="min-h-11" onClick={() => window.location.reload()}>{messages.createAnother}</Button>
      </div>
    );
  }

  return (
    <form action={action} className="space-y-5" aria-describedby={statusId} noValidate>
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <div className="space-y-2">
        <Label htmlFor="invitation-organization">{messages.organizationLabel}</Label>
        <select id="invitation-organization" name="organizationId" required className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50">
          {organizations.map((organization) => <option key={organization.id} value={organization.id}>{organization.displayName}</option>)}
        </select>
      </div>
      <div className="space-y-2">
        <Label htmlFor="invited-email">{messages.userIdLabel}</Label>
        <Input id="invited-email" name="invitedEmail" type="email" inputMode="email" autoComplete="email" required dir="ltr" spellCheck={false} autoCapitalize="none" autoCorrect="off" className="min-h-11 text-start" aria-describedby="invited-email-hint" />
        <p id="invited-email-hint" className="text-xs leading-5 text-muted-foreground">{messages.userIdHint}</p>
      </div>
      <fieldset className="space-y-3" aria-describedby={rolesHintId}>
        <legend className="text-sm font-medium">{messages.rolesLegend}</legend>
        <p id={rolesHintId} className="sr-only">{messages.createDescription}</p>
        <div className="grid gap-3 sm:grid-cols-2">
          {roleGroups.flat().map((role) => (
            <label key={role} className="flex min-h-11 cursor-pointer items-start gap-3 rounded-lg border bg-background p-3 text-sm leading-5 has-[:checked]:border-primary/60 has-[:checked]:bg-primary/5">
              <input name="roleCodes" value={role} type="checkbox" className="mt-0.5 size-5 shrink-0 accent-primary" />
              <span>{messages.roles[role]}</span>
            </label>
          ))}
        </div>
      </fieldset>
      <div className="space-y-2">
        <Label htmlFor="invitation-expiry">{messages.expiryLabel}</Label>
        <select id="invitation-expiry" name="expiryDays" defaultValue="7" required className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50">
          {(["1", "7", "14", "30"] as const).map((days) => <option key={days} value={days}>{messages.expiry[days]}</option>)}
        </select>
      </div>
      <Button type="submit" className="min-h-11 w-full sm:w-auto" disabled={pending}>{pending ? messages.sending : messages.send}</Button>
      <p id={statusId} role={error ? "alert" : "status"} aria-live="polite" className={error ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>
        {error ?? ""}
      </p>
    </form>
  );
}
