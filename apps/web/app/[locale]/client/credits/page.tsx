import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { createServerCreditsRepository } from "@/lib/credits-wallet/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { getServerTimestamp } from "@/lib/time/server-clock";
import { BenefitAction } from "./benefit-action";
import { messages } from "./messages";
import { RedemptionActions } from "./redemption-actions";
import { WalletAction } from "./wallet-action";

export default async function Credits({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await (await createServerCreditsRepository()).load();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") throw new Error("CREDITS_UNAVAILABLE");

  const data = result.value;
  const m = messages(locale);
  const today = getServerTimestamp();

  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-6xl space-y-7">
    <header><h1 className="text-3xl font-semibold">{m.title}</h1><p className="mt-2 max-w-3xl text-muted-foreground">{m.intro}</p></header>

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
  </div></main>;
}
