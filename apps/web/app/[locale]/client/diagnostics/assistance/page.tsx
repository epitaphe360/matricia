import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { AssistancePanel } from "@/modules/client/screens/diagnostics/assistance/assistance-panel";
import { getAssistanceMessages } from "@/modules/client/screens/diagnostics/assistance/messages";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { createServerAssistedIntelligenceRepository } from "@/modules/shared/lib/assisted-intelligence/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AssistancePage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const messages = getAssistanceMessages(locale);
  const result = await (await createServerAssistedIntelligenceRepository()).dashboard();
  const kicker = spaceCopy(locale).kicker;
  if (result.status === "error") {
    const forbidden = result.reason === "FORBIDDEN";
    return (
      <ClientAppShell
        locale={locale}
        selectedQuery={space.selectedQuery}
        selectedOrganizationId={space.selectedOrganizationId}
        userEmail={space.userEmail}
        active="needs"
        title={forbidden ? messages.forbiddenTitle : messages.errorTitle}
        lead={forbidden ? messages.forbidden : messages.error}
        kicker={kicker}
      >
        <main className="client-page" role={forbidden ? undefined : "alert"}>
          <p>{forbidden ? messages.forbidden : messages.error}</p>
        </main>
      </ClientAppShell>
    );
  }
  const decisionKeys = Object.fromEntries(result.value.suggestions.map((suggestion) => [suggestion.id, randomUUID()]));
  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="needs"
      title={messages.title}
      lead={messages.intro}
      kicker={kicker}
    >
      <main className="client-page space-y-6">
        <p className="rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm font-medium text-primary">{messages.safety}</p>
        {result.value.model ? (
          <p className="text-sm text-muted-foreground">{messages.model}: <span dir="ltr" className="font-mono">v{result.value.model.version} · {result.value.model.algorithm}</span></p>
        ) : null}
        <AssistancePanel
          dashboard={result.value}
          locale={locale}
          messages={messages}
          keys={{ analysis: randomUUID(), similarity: randomUUID(), decisions: decisionKeys }}
        />
      </main>
    </ClientAppShell>
  );
}
