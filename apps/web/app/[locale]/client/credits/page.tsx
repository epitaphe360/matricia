import { randomUUID } from "node:crypto";
import type { ReactNode } from "react";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Badge } from "@/modules/shared/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { resolveClientOrganizationContext } from "@/modules/shared/client-organization-context";
import { createServerCreditsRepository } from "@/modules/shared/lib/credits-wallet/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getServerTimestamp } from "@/modules/shared/lib/time/server-clock";
import { BenefitAction } from "@/modules/client/screens/credits/benefit-action";
import { messages } from "@/modules/client/screens/credits/messages";
import { RedemptionActions } from "@/modules/client/screens/credits/redemption-actions";
import { WalletAction } from "@/modules/client/screens/credits/wallet-action";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import Link from "next/link";

export default async function Credits({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/client/credits` }));
  const result = await (await createServerCreditsRepository(organizationId)).load();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/client/credits` }));
  const m = messages(locale);
  const c = spaceCopy(locale);
  const shell = (body: ReactNode) => (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="finance" title={m.title} lead={m.intro} kicker={c.kicker}>
      <main className="client-page">{body}</main>
    </ClientAppShell>
  );
  if (result.status === "error") return shell(<p role="alert" className="client-card">{m.unavailable}</p>);

  const context = resolveClientOrganizationContext(result.value.organizations.map((organization) => ({ organization_id: organization.id, name: organization.name })), organizationId);
  if (context.status === "error" && context.reason === "ORGANIZATION_SELECTION_REQUIRED") {
    return shell(
      <section className="client-card">
        <h2>{m.selectOrg}</h2>
        <ul className="client-feed">
          {result.value.organizations.map((organization) => (
            <li key={organization.id}><Link href={`/${locale}/client/credits?organizationId=${organization.id}`}>{organization.name}</Link></li>
          ))}
        </ul>
      </section>,
    );
  }
  if (context.status === "error") return shell(<p role="alert" className="client-card">{context.reason === "NO_CLIENT_ORGANIZATION" ? m.noOrg : m.unavailable}</p>);
  const selectedOrganizationId = context.membership.organization_id;
  const selectedWalletIds = new Set(result.value.wallets.filter((wallet) => wallet.organizationId === selectedOrganizationId).map((wallet) => wallet.id));
  const data = {
    ...result.value,
    organizations: result.value.organizations.filter((organization) => organization.id === selectedOrganizationId),
    wallets: result.value.wallets.filter((wallet) => wallet.organizationId === selectedOrganizationId),
    lots: result.value.lots.filter((lot) => selectedWalletIds.has(lot.walletId)),
    customerBoxes: result.value.customerBoxes.filter((box) => box.organizationId === selectedOrganizationId),
    redemptions: result.value.redemptions.filter((redemption) => redemption.organizationId === selectedOrganizationId),
  };
  const today = getServerTimestamp();

  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="finance" title={m.title} lead={m.intro} kicker={c.kicker}>
    <main className="client-page">

    <section aria-labelledby="wallets"><h2 id="wallets" className="mb-3 text-xl font-semibold">{m.wallet}</h2><div className="grid gap-4 sm:grid-cols-2">
      {data.organizations.map(organization => {
        const wallet = data.wallets.find(item => item.organizationId === organization.id);
        const lots = wallet ? data.lots.filter(item => item.walletId === wallet.id) : [];
        return <Card key={organization.id}><CardHeader><CardTitle>{organization.name}</CardTitle></CardHeader><CardContent>{wallet ? <>
          <p>{m.balance}: <strong dir="ltr">{wallet.balance} {wallet.unitCode}</strong></p>
          <h3 className="mt-4 font-medium">{m.lots}</h3>
          {lots.length === 0 ? <p className="mt-2 text-sm text-muted-foreground">{m.empty}</p> : <ul className="mt-2 space-y-3">
            {lots.map(lot => { const expired = new Date(lot.expiresAt).getTime() <= today; return <li key={lot.id} className="rounded-lg border p-3 text-sm">
              <div className="flex flex-wrap items-center justify-between gap-2"><span>{m.source}: {lot.sourceType}</span><Badge variant={expired ? "secondary" : "outline"}>{expired ? m.expiredLot : m.activeLot}</Badge></div>
              <dl className="mt-2 grid grid-cols-2 gap-2"><div><dt className="text-muted-foreground">{m.initialQuantity}</dt><dd dir="ltr">{lot.quantity}</dd></div><div><dt className="text-muted-foreground">{m.available}</dt><dd dir="ltr">{lot.available ?? lot.quantity}</dd></div><div><dt className="text-muted-foreground">{m.reservedLot}</dt><dd dir="ltr">{lot.reserved ?? "0"}</dd></div><div><dt className="text-muted-foreground">{m.expires}</dt><dd>{new Date(lot.expiresAt).toLocaleDateString(locale)}</dd></div></dl>
            </li>; })}
          </ul>}
        </> : <><p className="mb-3">{m.noWallet}</p><WalletAction locale={locale} organizationId={organization.id} keyValue={randomUUID()} m={m}/></>}</CardContent></Card>;
      })}
    </div></section>

    <section aria-labelledby="boxes"><h2 id="boxes" className="mb-3 text-xl font-semibold">{m.boxes}</h2>{data.customerBoxes.length === 0 ? <p className="text-muted-foreground">{m.noBoxes}</p> : <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {data.customerBoxes.map(customerBox => { const box = data.boxes.find(item => item.id === customerBox.boxVersionId); return box ? <Card key={customerBox.id}><CardHeader><CardTitle>{locale === "ar" ? box.nameAr : box.nameFr}</CardTitle><CardDescription>{new Date(customerBox.periodStart).toLocaleDateString(locale)} — {new Date(customerBox.periodEnd).toLocaleDateString(locale)}</CardDescription></CardHeader><CardContent className="space-y-1 text-sm"><p>{m.version}: <span dir="ltr">{box.version ?? "—"}</span></p><p>{m.boxType}: {box.type ?? "—"}</p><p>{m.balance}: <strong dir="ltr">{box.creditBudget} {box.currency}</strong></p><p>{m.rollover}: <span dir="ltr">{box.rolloverMonths}</span> {m.months}</p></CardContent></Card> : null; })}
    </div>}</section>

    <section aria-labelledby="benefits"><h2 id="benefits" className="mb-3 text-xl font-semibold">{m.catalog}</h2>{data.benefits.length === 0 ? <p className="text-muted-foreground">{m.noBenefits}</p> : <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {data.benefits.map(benefit => <Card key={benefit.id}><CardHeader><CardTitle>{locale === "ar" ? benefit.nameAr : benefit.nameFr}</CardTitle><CardDescription>{locale === "ar" ? benefit.descriptionAr : benefit.descriptionFr}</CardDescription></CardHeader><CardContent><dl className="mb-3 space-y-1 text-sm"><div><dt className="inline text-muted-foreground">{m.version}: </dt><dd className="inline" dir="ltr">{benefit.version ?? "—"}</dd></div><div><dt className="inline text-muted-foreground">{m.benefitType}: </dt><dd className="inline">{benefit.type ?? "—"}</dd></div><div><dt className="inline text-muted-foreground">{m.fulfillment}: </dt><dd className="inline">{benefit.fulfillmentMode ?? "—"}</dd></div>{benefit.effectiveFrom ? <div><dt className="inline text-muted-foreground">{m.effectiveFrom}: </dt><dd className="inline">{new Date(benefit.effectiveFrom).toLocaleDateString(locale)}</dd></div> : null}</dl><p>{m.cost}: <strong dir="ltr">{benefit.creditCost}</strong></p>{data.wallets.map(wallet => <BenefitAction key={wallet.id} locale={locale} b={benefit} wallet={wallet} walletLabel={data.organizations.find(item => item.id === wallet.organizationId)?.name ?? wallet.organizationId} m={m} keyValue={randomUUID()}/>)}</CardContent></Card>)}
    </div>}</section>

    <section aria-labelledby="redemptions"><h2 id="redemptions" className="mb-3 text-xl font-semibold">{m.redemptions}</h2>{data.redemptions.length === 0 ? <p className="text-muted-foreground">{m.noRedemptions}</p> : data.redemptions.map(redemption => <Card key={redemption.id} className="mb-4"><CardHeader><div className="flex justify-between gap-3"><CardTitle dir="ltr">{redemption.reservedCredits}</CardTitle><Badge>{m.statuses[redemption.status as keyof typeof m.statuses] ?? redemption.status}</Badge></div></CardHeader><CardContent><p>{m.expires}: {new Date(redemption.expiresAt).toLocaleString(locale)}</p><RedemptionActions locale={locale} r={redemption} m={m} keys={{release:randomUUID(), consume:randomUUID()}}/></CardContent></Card>)}</section>
    </main>
    </ClientAppShell>
  );
}
