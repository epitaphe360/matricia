import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { listInvitations, type SafeInvitation } from "./actions";
import { InvitationDecisionForm } from "./invitation-decision-form";
import { InviteForm } from "./invite-form";
import { getInvitationMessages, type InvitationMessages } from "./messages";

function dateLabel(value: string, locale: Locale): string {
  const date = new Date(value);
  return new Intl.DateTimeFormat(locale === "fr" ? "fr-MA" : "ar-MA", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function InvitationCard({ invitation, locale, messages }: { invitation: SafeInvitation; locale: Locale; messages: InvitationMessages }) {
  const canDecide = invitation.direction === "RECEIVED" && invitation.status === "PENDING";
  return (
    <Card>
      <CardHeader className="space-y-3">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div className="min-w-0">
            <CardTitle className="break-words text-lg">{invitation.organizationName ?? messages.unknownOrganization}</CardTitle>
            {invitation.direction === "MANAGED" ? <CardDescription>{messages.invitedMember}</CardDescription> : null}
          </div>
          <Badge variant="outline">{messages.statuses[invitation.status]}</Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <p className="text-sm font-medium">{messages.rolesLabel}</p>
          {invitation.roles.length > 0 ? (
            <ul className="mt-2 flex flex-wrap gap-2" aria-label={messages.rolesLabel}>
              {invitation.roles.map((role) => <li key={role}><Badge variant="secondary">{messages.roles[role]}</Badge></li>)}
            </ul>
          ) : <p className="mt-1 text-sm text-muted-foreground">{messages.noRoles}</p>}
        </div>
        <dl className="grid gap-3 text-sm sm:grid-cols-2">
          <div><dt className="text-muted-foreground">{messages.createdAt}</dt><dd className="mt-1 font-medium"><time dateTime={invitation.createdAt}>{dateLabel(invitation.createdAt, locale)}</time></dd></div>
          <div><dt className="text-muted-foreground">{messages.expiresAt}</dt><dd className="mt-1 font-medium"><time dateTime={invitation.expiresAt}>{dateLabel(invitation.expiresAt, locale)}</time></dd></div>
        </dl>
        {canDecide ? (
          <div className="grid gap-4 border-t pt-4 sm:grid-cols-2">
            <InvitationDecisionForm invitationId={invitation.id} locale={locale} mode="accept" messages={messages} />
            <InvitationDecisionForm invitationId={invitation.id} locale={locale} mode="decline" messages={messages} />
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}

export default async function InvitationsPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await listInvitations();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getInvitationMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";

  if (result.status === "error") {
    return (
      <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
        <div className="mx-auto max-w-4xl space-y-6">
          <Alert variant="destructive">
            <AlertTitle>{messages.loadErrorTitle}</AlertTitle>
            <AlertDescription>
              <p>{messages.loadErrorDescription}</p>
              <Link href={`/${locale}/invitations`} className={cn(buttonVariants({ variant: "outline" }), "mt-2 min-h-11")}>{messages.retry}</Link>
            </AlertDescription>
          </Alert>
        </div>
      </main>
    );
  }

  const received = result.invitations.filter((invitation) => invitation.direction === "RECEIVED");
  const managed = result.invitations.filter((invitation) => invitation.direction === "MANAGED");
  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-5xl space-y-8">
        <header className="space-y-4">
          <nav aria-label={messages.navigationLabel} className="flex flex-wrap items-center justify-between gap-3">
            <Link href={`/${locale}/tableau-de-bord`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.backToDashboard}</Link>
            <Link href={`/${alternate}/invitations`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link>
          </nav>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1>
            <p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p>
          </div>
        </header>

        <Card className="shadow-lg">
          <CardHeader><CardTitle>{messages.createTitle}</CardTitle><CardDescription>{messages.createDescription}</CardDescription></CardHeader>
          <CardContent><InviteForm locale={locale} organizations={result.organizations} messages={messages} idempotencyKey={randomUUID()} /></CardContent>
        </Card>

        <section aria-labelledby="received-invitations-title" className="space-y-4">
          <h2 id="received-invitations-title" className="text-2xl font-semibold">{messages.receivedTitle}</h2>
          {received.length === 0 ? <p className="rounded-lg border bg-card p-5 text-sm text-muted-foreground">{messages.receivedEmpty}</p> : (
            <ul className="grid gap-4">{received.map((invitation) => <li key={invitation.id}><InvitationCard invitation={invitation} locale={locale} messages={messages} /></li>)}</ul>
          )}
        </section>

        <section aria-labelledby="managed-invitations-title" className="space-y-4">
          <h2 id="managed-invitations-title" className="text-2xl font-semibold">{messages.managedTitle}</h2>
          {managed.length === 0 ? <p className="rounded-lg border bg-card p-5 text-sm text-muted-foreground">{messages.managedEmpty}</p> : (
            <ul className="grid gap-4 sm:grid-cols-2">{managed.map((invitation) => <li key={invitation.id}><InvitationCard invitation={invitation} locale={locale} messages={messages} /></li>)}</ul>
          )}
        </section>
      </div>
    </main>
  );
}
