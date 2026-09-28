import Link from "next/link";
import { formatMinor, type SubscriptionSummary } from "@/modules/shared/lib/subscriptions/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

type Cycle = SubscriptionSummary["cycles"][number];

export function SubscriptionInvoice({
  locale,
  query,
  organizationName,
  cycle,
}: {
  locale: Locale;
  query: string;
  organizationName: string;
  cycle: Cycle;
}) {
  const ar = locale === "ar";
  return (
    <article className="client-card">
      <header className="client-priority-head">
        <h2>{ar ? "فاتورة الاشتراك" : "Facture d’abonnement"}</h2>
        <span className="client-status-chip" data-tone="mint">{ar ? "مدفوعة" : "Réglée"}</span>
      </header>
      <p>{organizationName}</p>
      <dl className="client-brief-kpis">
        <div><dt>{ar ? "الدورة" : "Cycle"}</dt><dd dir="ltr">{cycle.cycleNumber}</dd></div>
        <div><dt>{ar ? "الخطة" : "Plan"}</dt><dd dir="ltr">{cycle.plan.code} · v{cycle.plan.version}</dd></div>
        <div><dt>{ar ? "الفترة" : "Période"}</dt><dd dir="ltr">{cycle.periodStart} — {cycle.periodEnd}</dd></div>
        <div><dt>{ar ? "المبلغ" : "Montant"}</dt><dd dir="ltr">{formatMinor(cycle.amountMinor, cycle.currency, locale)}</dd></div>
        {cycle.paymentReference ? <div><dt>{ar ? "مرجع الدفع" : "Référence de paiement"}</dt><dd dir="ltr">{cycle.paymentReference}</dd></div> : null}
      </dl>
      <Link href={`/${locale}/client/abonnement${query}#factures`} className="client-text-link">{ar ? "العودة إلى الفواتير" : "Retour aux factures"}</Link>
    </article>
  );
}
