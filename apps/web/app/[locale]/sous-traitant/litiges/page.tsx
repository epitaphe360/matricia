import { notFound, redirect } from "next/navigation";
import { resolveProviderSpace } from "@/modules/provider/data/spaces/context";
import { getProviderDisputeMessages } from "@/modules/provider/screens/litiges/messages";
import { ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";
import { DisputesBoard } from "@/modules/client/screens/spaces/disputes-board";
import { createServerDisputesRepository } from "@/modules/shared/lib/disputes/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ProviderDisputesPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveProviderSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const repository = await createServerDisputesRepository(space.selectedOrganizationId ?? query.organizationId, "provider");
  const result = await repository.list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") throw new Error("PROVIDER_DISPUTES_UNAVAILABLE");
  const selectedId = result.value.cases[0]?.id;
  const selected = selectedId ? await repository.detail(selectedId) : { status: "success" as const, value: null };
  if (selected.status === "error" && selected.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const m = getProviderDisputeMessages(locale);
  return (
    <ProviderAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="disputes" title={m.title} lead={m.intro}>
      <DisputesBoard
        locale={locale}
        query={space.selectedQuery}
        organizationName={space.organizationName}
        cases={result.value.cases}
        selected={selected.status === "success" ? selected.value : null}
        messages={m}
        canOpen={false}
        hrefPrefix={`/${locale}/sous-traitant/litiges`}
      />
    </ProviderAppShell>
  );
}
