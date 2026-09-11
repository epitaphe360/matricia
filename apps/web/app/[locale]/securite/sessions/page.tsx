import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { listMySessions, type SafeSession } from "./actions";
import { RevokeSessionForm } from "./revoke-session-form";

function dateLabel(value: string | null, locale: Locale, unavailable: string) {
  if (!value) return unavailable;
  const normalized = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?$/.test(value) ? `${value}Z` : value;
  const date = new Date(normalized);
  if (Number.isNaN(date.getTime())) return unavailable;
  return new Intl.DateTimeFormat(locale === "fr" ? "fr-MA" : "ar-MA", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function deviceLabel(session: SafeSession, labels: { unknownDevice: string; mobileDevice: string; desktopDevice: string }) {
  if (!session.userAgent) return labels.unknownDevice;
  return /Mobile|Android|iPhone|iPad/i.test(session.userAgent) ? labels.mobileDevice : labels.desktopDevice;
}

export default async function SessionsPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await listMySessions();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getDictionary(locale).sessions;
  const alternate = locale === "fr" ? "ar" : "fr";

  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-4xl space-y-6">
        <header className="space-y-4">
          <nav aria-label={messages.navigationLabel} className="flex flex-wrap items-center justify-between gap-3">
            <Link href={`/${locale}/tableau-de-bord`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.backToDashboard}</Link>
            <Link href={`/${alternate}/securite/sessions`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary">{messages.language}</Link>
          </nav>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1>
            <p className="mt-3 max-w-2xl text-muted-foreground">{messages.description}</p>
          </div>
        </header>

        {result.status === "error" ? (
          <Alert variant="destructive">
            <AlertTitle>{messages.loadErrorTitle}</AlertTitle>
            <AlertDescription>
              <p>{messages.loadErrorDescription}</p>
              <Link href={`/${locale}/securite/sessions`} className={cn(buttonVariants({ variant: "outline" }), "mt-2 min-h-11")}>{messages.retry}</Link>
            </AlertDescription>
          </Alert>
        ) : result.sessions.length === 0 ? (
          <Card>
            <CardHeader>
              <CardTitle>{messages.emptyTitle}</CardTitle>
              <CardDescription>{messages.emptyDescription}</CardDescription>
            </CardHeader>
          </Card>
        ) : (
          <section aria-labelledby="session-list-title" className="space-y-4">
            <h2 id="session-list-title" className="text-xl font-semibold">{messages.listTitle}</h2>
            <ul className="grid gap-4">
              {result.sessions.map((session) => (
                <li key={session.id}>
                  <Card className={session.isCurrent ? "border-primary/50" : undefined}>
                    <CardHeader>
                      <div className="flex flex-wrap items-center justify-between gap-3">
                        <CardTitle>{deviceLabel(session, messages)}</CardTitle>
                        {session.isCurrent ? <Badge>{messages.current}</Badge> : null}
                      </div>
                      <CardDescription dir="ltr" className="break-words text-start">{session.userAgent ?? messages.userAgentUnavailable}</CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-4">
                      <dl className="grid gap-3 text-sm sm:grid-cols-3">
                        <div><dt className="text-muted-foreground">{messages.lastActive}</dt><dd className="mt-1 font-medium">{dateLabel(session.lastSeenAt, locale, messages.dateUnavailable)}</dd></div>
                        <div><dt className="text-muted-foreground">{messages.created}</dt><dd className="mt-1 font-medium">{dateLabel(session.createdAt, locale, messages.dateUnavailable)}</dd></div>
                        <div><dt className="text-muted-foreground">{messages.expires}</dt><dd className="mt-1 font-medium">{dateLabel(session.expiresAt, locale, messages.dateUnavailable)}</dd></div>
                      </dl>
                      {session.isCurrent ? (
                        <p className="rounded-lg border border-primary/30 bg-primary/5 p-3 text-sm">{messages.currentProtection}</p>
                      ) : (
                        <RevokeSessionForm sessionId={session.id} locale={locale} messages={messages.revokeForm} />
                      )}
                    </CardContent>
                  </Card>
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </main>
  );
}
