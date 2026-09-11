import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { listOrganizationRoles } from "./actions";
import { getRoleMessages } from "./messages";
import { RoleDecisionForm } from "./role-decision-form";
import { RoleRequestForm } from "./role-request-form";

function dateLabel(value: string, locale: Locale): string {
  return new Intl.DateTimeFormat(locale === "fr" ? "fr-MA" : "ar-MA", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function OrganizationRolesPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await listOrganizationRoles();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect("/" + locale + "/connexion");
  const messages = getRoleMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";

  if (result.status === "error") {
    return (
      <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
        <div className="mx-auto max-w-5xl">
          <Alert variant="destructive">
            <AlertTitle>{messages.loadErrorTitle}</AlertTitle>
            <AlertDescription>
              <p>{messages.loadError}</p>
              <Link href={"/" + locale + "/organisation/roles"} className={cn(buttonVariants({ variant: "outline" }), "mt-2 min-h-11")}>{messages.retry}</Link>
            </AlertDescription>
          </Alert>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-5xl space-y-8">
        <header className="space-y-4">
          <nav aria-label={messages.navigation} className="flex flex-wrap items-center justify-between gap-3">
            <Link href={"/" + locale + "/organisation"} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link>
            <Link href={"/" + alternate + "/organisation/roles"} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link>
          </nav>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1>
            <p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p>
          </div>
        </header>

        <Card className="shadow-lg">
          <CardHeader><CardTitle>{messages.requestTitle}</CardTitle><CardDescription>{messages.requestDescription}</CardDescription></CardHeader>
          <CardContent><RoleRequestForm locale={locale} organizations={result.organizations} idempotencyKey={randomUUID()} messages={messages} /></CardContent>
        </Card>

        <section aria-labelledby="memberships-title" className="space-y-4">
          <h2 id="memberships-title" className="text-2xl font-semibold">{messages.membershipsTitle}</h2>
          {result.memberships.length === 0 ? <p className="rounded-lg border bg-card p-5 text-sm text-muted-foreground">{messages.membershipsEmpty}</p> : (
            <ul className="grid gap-4 sm:grid-cols-2">
              {result.memberships.map((membership) => (
                <li key={membership.id}>
                  <Card className={membership.isCurrentUser ? "border-primary/50" : undefined}>
                    <CardHeader>
                      <div className="flex flex-wrap items-start justify-between gap-3">
                        <div><CardTitle className="text-lg">{membership.organizationName ?? messages.unknownOrganization}</CardTitle><CardDescription>{membership.isCurrentUser ? messages.you : messages.anotherMember}</CardDescription></div>
                        <Badge variant="outline">{messages.membershipStatuses[membership.status]}</Badge>
                      </div>
                    </CardHeader>
                    <CardContent>
                      {membership.roles.length > 0 ? <ul className="flex flex-wrap gap-2">{membership.roles.map((role) => <li key={role}><Badge variant="secondary">{messages.roles[role]}</Badge></li>)}</ul> : <p className="text-sm text-muted-foreground">{messages.noRole}</p>}
                    </CardContent>
                  </Card>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section aria-labelledby="requests-title" className="space-y-4">
          <h2 id="requests-title" className="text-2xl font-semibold">{messages.requestsTitle}</h2>
          {result.requests.length === 0 ? <p className="rounded-lg border bg-card p-5 text-sm text-muted-foreground">{messages.requestsEmpty}</p> : (
            <ul className="grid gap-4">
              {result.requests.map((request) => (
                <li key={request.id}>
                  <Card>
                    <CardHeader>
                      <div className="flex flex-wrap items-start justify-between gap-3">
                        <div>
                          <CardTitle className="text-lg">{request.organizationName ?? messages.unknownOrganization}</CardTitle>
                          <CardDescription>{request.isOwn ? messages.ownRequest : messages.memberRequest}</CardDescription>
                        </div>
                        <Badge variant="outline">{messages.requestStatuses[request.status]}</Badge>
                      </div>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <p className="font-medium">{messages.roles[request.requestedRole]}</p>
                      {request.requiresCentralApproval ? <p className="rounded-lg border border-primary/30 bg-primary/5 p-3 text-sm">{messages.centralRequired}</p> : null}
                      <dl className="grid gap-3 text-sm sm:grid-cols-2">
                        <div><dt className="text-muted-foreground">{messages.created}</dt><dd className="mt-1"><time dateTime={request.createdAt}>{dateLabel(request.createdAt, locale)}</time></dd></div>
                        {request.decidedAt ? <div><dt className="text-muted-foreground">{messages.decided}</dt><dd className="mt-1"><time dateTime={request.decidedAt}>{dateLabel(request.decidedAt, locale)}</time></dd></div> : null}
                      </dl>
                      {request.canDecide ? (
                        <div className="grid gap-4 border-t pt-4 sm:grid-cols-2">
                          <RoleDecisionForm requestId={request.id} locale={locale} decision="APPROVE" messages={messages} />
                          <RoleDecisionForm requestId={request.id} locale={locale} decision="REJECT" messages={messages} />
                        </div>
                      ) : null}
                    </CardContent>
                  </Card>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </main>
  );
}
