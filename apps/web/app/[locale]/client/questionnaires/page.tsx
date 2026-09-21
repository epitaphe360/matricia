import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { createServerQuestionnaireSessionsRepository } from "@/modules/shared/lib/questionnaire-sessions/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { getQuestionnaireMessages } from "@/modules/client/screens/questionnaires/messages";
import { QuestionnairePanel } from "@/modules/client/screens/questionnaires/questionnaire-panel";
import { loadClientPortfolio } from "@/modules/client/data/portfolio/server-repository";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function ClientQuestionnairesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ session?: string; organizationId?: string }> }) {
  const { locale } = await params;
  const { session, organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const messages = getQuestionnaireMessages(locale);
  const repository = await createServerQuestionnaireSessionsRepository();
  const [result, portfolio] = await Promise.all([repository.load(session, organizationId), loadClientPortfolio(organizationId ?? space.selectedOrganizationId ?? undefined)]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const sites = portfolio.status === "success" ? portfolio.value.sites.map((site) => ({ id: site.id, nameFr: site.nameFr, nameAr: site.nameAr })) : [];
  const alternate = locale === "fr" ? "ar" : "fr";
  const query = new URLSearchParams({ ...(session ? { session } : {}), ...(organizationId ? { organizationId } : {}) }).toString();
  const organizationQuery = organizationId ? `?organizationId=${encodeURIComponent(organizationId)}` : "";
  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="needs"
      title={messages.title}
      lead={messages.description}
      kicker={spaceCopy(locale).kicker}
      actions={<Link href={`/${alternate}/client/questionnaires${query ? `?${query}` : ""}`} hrefLang={alternate} className="client-soft-link">{messages.language}</Link>}
    >
      <main className="client-page space-y-6">
        <Alert>
          <AlertTitle>{messages.privacyTitle}</AlertTitle>
          <AlertDescription>{messages.privacy}</AlertDescription>
        </Alert>
        {result.status === "error" ? (
          <Alert variant="destructive">
            <AlertTitle>{result.reason === "FORBIDDEN" ? messages.forbidden : result.reason === "BOUNDS_EXCEEDED" ? messages.bounds : messages.loadError}</AlertTitle>
            <AlertDescription><Link className="underline" href={`/${locale}/client/questionnaires${organizationQuery}`}>{messages.retry}</Link></AlertDescription>
          </Alert>
        ) : (
          <QuestionnairePanel
            locale={locale}
            dashboard={result.value}
            messages={messages}
            sites={sites}
            identities={{
              start: { idempotencyKey: randomUUID(), correlationId: randomUUID() },
              submit: { idempotencyKey: randomUUID(), correlationId: randomUUID() },
              answers: Object.fromEntries((result.value.selected?.sections ?? []).flatMap((section) => section.questions.map((question) => [question.id, { idempotencyKey: randomUUID(), correlationId: randomUUID() }]))),
            }}
          />
        )}
      </main>
    </ClientAppShell>
  );
}
