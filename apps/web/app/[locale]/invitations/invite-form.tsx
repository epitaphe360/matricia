"use client";

import { useActionState, useId } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { Locale } from "@/lib/i18n/locale";
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
}: {
  locale: Locale;
  organizations: InvitationOrganization[];
  messages: InvitationMessages;
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

  return (
    <form action={action} className="space-y-5" aria-describedby={statusId} noValidate>
      <input type="hidden" name="locale" value={locale} />
      <div className="space-y-2">
        <Label htmlFor="invitation-organization">{messages.organizationLabel}</Label>
        <select id="invitation-organization" name="organizationId" required className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50">
          {organizations.map((organization) => <option key={organization.id} value={organization.id}>{organization.displayName}</option>)}
        </select>
      </div>
      <div className="space-y-2">
        <Label htmlFor="invited-user-id">{messages.userIdLabel}</Label>
        <Input id="invited-user-id" name="invitedUserId" type="text" inputMode="text" required dir="ltr" spellCheck={false} autoCapitalize="none" autoCorrect="off" className="min-h-11 text-start" aria-describedby="invited-user-id-hint" />
        <p id="invited-user-id-hint" className="text-xs leading-5 text-muted-foreground">{messages.userIdHint}</p>
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
        {error ?? (state.status === "success" ? messages.sent : "")}
      </p>
    </form>
  );
}
