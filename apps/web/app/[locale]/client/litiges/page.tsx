import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { DisputesBoard } from "@/modules/client/screens/spaces/disputes-board";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { getDisputeMessages } from "@/modules/client/screens/litiges/messages";
import { createServerDisputesRepository } from "@/modules/shared/lib/disputes/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function DisputesPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();

  const space = await resolveClientSpace({ locale, organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);

  const repository = await createServerDisputesRepository(space.selectedOrganizationId ?? organizationId);
  const result = await repository.list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") throw new Error("DISPUTES_UNAVAILABLE");

  const selectedId = result.value.cases[0]?.id;
  const selected = selectedId ? await repository.detail(selectedId) : { status: "success" as const, value: null };
  if (selected.status === "error" && selected.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);

  const m = getDisputeMessages(locale);
  const c = spaceCopy(locale);

  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      title={m.title}
      lead={m.intro}
      kicker={space.organizationName ?? c.kicker}
      actions={
        result.value.canOpen ? (
          <Link href={`/${locale}/client/litiges/nouveau${space.selectedQuery}`} className="client-cta">
            {m.newCase}
          </Link>
        ) : (
          <Link href={`/${locale}/contact${space.selectedQuery}`} className="client-cta">
            {c.contactAssist}
          </Link>
        )
      }
    >
      <DisputesBoard
        locale={locale}
        query={space.selectedQuery}
        organizationName={space.organizationName}
        cases={result.value.cases}
        selected={selected.status === "success" ? selected.value : null}
        messages={m}
        canOpen={result.value.canOpen}
      />
    </ClientAppShell>
  );
}
