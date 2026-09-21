import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { getDisputeMessages } from "@/modules/client/screens/litiges/messages";
import { OpenForm } from "@/modules/client/screens/litiges/open-form";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { createServerDisputesRepository } from "@/modules/shared/lib/disputes/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function NewDispute({
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
  const result = await (await createServerDisputesRepository(query.organizationId)).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") throw new Error("DISPUTES_UNAVAILABLE");
  if (!result.value.canOpen) redirect(`/${locale}/client/litiges${space.selectedQuery}`);
  const m = getDisputeMessages(locale);
  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="missions"
      title={m.newCase}
      kicker={spaceCopy(locale).kicker}
    >
      <main className="client-page">
        <Card>
          <CardHeader><CardTitle>{m.newCase}</CardTitle></CardHeader>
          <CardContent>
            <OpenForm locale={locale} missions={result.value.missions} m={m} keyValue={randomUUID()} />
          </CardContent>
        </Card>
      </main>
    </ClientAppShell>
  );
}
