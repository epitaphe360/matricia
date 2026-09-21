import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { getSubscriptionMessages } from "@/modules/client/screens/abonnement/messages";
import { SubscriptionPanel } from "@/modules/client/screens/abonnement/subscription-panel";
import { SubscriptionBoard } from "@/modules/client/screens/spaces/subscription-board";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { createServerCreditsRepository } from "@/modules/shared/lib/credits-wallet/server-repository";
import { loadSubscriptionDashboard } from "@/modules/shared/lib/subscriptions/repository";
import { listOrganizationRoles } from "@/app/[locale]/organisation/roles/actions";

export default async function SubscriptionPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const [result, creditsResult, roles] = await Promise.all([
    loadSubscriptionDashboard(organizationId),
    createServerCreditsRepository(organizationId).then((repository) => repository.load()),
    listOrganizationRoles(),
  ]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getSubscriptionMessages(locale);
  const c = spaceCopy(locale);
  if (result.status === "error") {
    return (
      <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="finance" title={c.subPageTitle} lead={c.subPageLead} kicker={c.kicker}>
        <p role="alert" className="client-card">{messages.error}</p>
      </ClientAppShell>
    );
  }
  const keys = Object.fromEntries(["trial", ...result.dashboard.plans.map((plan) => plan.id)].map((key) => [key, randomUUID()]));
  const selectedId = result.dashboard.organizationId;
  const wallets = creditsResult.status === "success" ? creditsResult.value.wallets.filter((wallet) => wallet.organizationId === selectedId) : [];
  const boxes = creditsResult.status === "success" ? creditsResult.value.customerBoxes.filter((box) => box.organizationId === selectedId) : [];
  const catalog = creditsResult.status === "success" ? creditsResult.value.boxes : [];
  const redemptions = creditsResult.status === "success" ? creditsResult.value.redemptions.filter((item) => item.organizationId === selectedId) : [];
  const members = roles.status === "success" ? roles.memberships.filter((item) => item.status === "ACTIVE") : [];
  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="finance" title={c.subPageTitle} lead={c.subPageLead} kicker={result.dashboard.organizationName}>
      <SubscriptionBoard
        locale={locale}
        query={space.selectedQuery}
        dashboard={result.dashboard}
        credits={{
          balance: wallets[0]?.balance ?? "0",
          unitCode: wallets[0]?.unitCode ?? "CRD",
          memberCount: members.length,
          boxes: boxes.map((box) => {
            const version = catalog.find((item) => item.id === box.boxVersionId);
            return {
              id: box.id,
              name: version ? (locale === "ar" ? version.nameAr : version.nameFr) : box.boxVersionId,
              budget: version ? `${version.creditBudget} ${version.currency}` : "—",
              href: `/${locale}/client/credits${space.selectedQuery}`,
            };
          }),
          operations: redemptions.slice(0, 6).map((item) => ({
            id: item.id,
            title: item.status,
            quantity: item.reservedCredits,
            href: `/${locale}/client/credits${space.selectedQuery}`,
          })),
        }}
      >
        <details className="client-ops">
          <summary>{messages.plans}</summary>
          <SubscriptionPanel dashboard={result.dashboard} locale={locale} messages={messages} keys={keys} />
        </details>
      </SubscriptionBoard>
    </ClientAppShell>
  );
}
