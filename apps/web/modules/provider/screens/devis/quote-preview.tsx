import Link from "next/link";
import { formatMinorExact } from "@/modules/client/data/rfq/model";
import type { ProviderQuoteDashboard } from "@/modules/provider/data/quotes/model";
import { workbenchCopy } from "@/modules/provider/data/spaces/workbench-copy";
import type { QuotePrefill } from "@/modules/provider/screens/devis/prefill";
import { getProviderQuoteMessages } from "@/modules/provider/screens/devis/messages";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { ReactNode } from "react";

function lines(value: string): string[] {
  return value.split(/\r?\n/u).map((item) => item.trim()).filter(Boolean);
}

export function QuotePreviewWorkbench({
  locale,
  query,
  quoteId,
  invitation,
  prefill,
  organizationName,
  submitPanel,
}: {
  locale: Locale;
  query: string;
  quoteId: string;
  invitation: ProviderQuoteDashboard["invitations"][number] | null;
  prefill?: QuotePrefill;
  organizationName: string;
  submitPanel?: ReactNode;
}) {
  const w = workbenchCopy(locale);
  const m = getProviderQuoteMessages(locale);
  const quote = invitation?.quote ?? null;
  const currency = invitation?.currency ?? quote?.currency ?? null;
  const editHref = `/${locale}/sous-traitant/devis/${quote?.id ?? quoteId}${query}`;
  const checks = [
    { ok: Boolean(prefill?.lines.length), label: w.quoteCheckLines },
    { ok: Boolean(prefill?.validUntil), label: w.quoteCheckDate },
    { ok: quote?.totalMinor !== null && quote?.totalMinor !== undefined, label: w.quoteCheckAmounts },
    { ok: Boolean(prefill?.solution && prefill.deliverables), label: w.quoteScopeOk },
  ];

  return (
    <main className="client-page provider-workbench provider-quote-preview">
      <p className="provider-breadcrumb">
        <Link href={`/${locale}/sous-traitant/devis${query}`} className="client-text-link">{w.quoteBackToList}</Link>
      </p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.quotePreviewTitle}</h2>
          <p>{w.quotePreviewLead}</p>
        </div>
        {quote?.status ? <span className="client-status-chip" data-tone="violet">{quote.status}</span> : null}
      </header>
      {!prefill || !quote || !currency || !invitation ? (
        <article className="client-card" role="status">
          <p>{w.quotePreviewEmpty}</p>
          <Link href={editHref} className="client-cta">{w.quoteBackToEdit}</Link>
        </article>
      ) : (
        <section className="provider-workbench-grid provider-quote-grid">
          <article className="client-card">
            <header><h3>{w.quoteClientView}</h3></header>
            <dl className="provider-quote-identity">
              <div><dt>{w.quoteConsultation}</dt><dd>{invitation.description}</dd></div>
              <div><dt>{w.quoteClient}</dt><dd>{w.quoteClientMasked}</dd></div>
              <div><dt>{w.quoteObject}</dt><dd>{prefill.solution}</dd></div>
              <div><dt>{locale === "ar" ? "المُصدر" : "Émetteur"}</dt><dd>{organizationName}</dd></div>
            </dl>
            <div className="client-table-wrap">
              <table className="client-space-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>{m.line}</th>
                    <th>{m.quantity}</th>
                    <th>{m.unit}</th>
                    <th>{m.unitPrice}</th>
                  </tr>
                </thead>
                <tbody>
                  {prefill.lines.map((line, index) => (
                    <tr key={`${line.label}-${index}`}>
                      <td dir="ltr">{index + 1}</td>
                      <td>{line.label}</td>
                      <td dir="ltr">{line.quantity}</td>
                      <td dir="ltr">{line.unitCode}</td>
                      <td dir="ltr">{line.unitPrice} {currency}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <p className="provider-money">
              <span>{m.subtotal}</span>
              <strong dir="ltr">{quote.subtotalMinor ? formatMinorExact(quote.subtotalMinor, currency, locale) : "—"}</strong>
            </p>
            <p className="provider-money">
              <span>{m.taxAmount}</span>
              <strong dir="ltr">{quote.taxMinor ? formatMinorExact(quote.taxMinor, currency, locale) : "—"}</strong>
            </p>
            <p className="provider-money">
              <span>{m.total}</span>
              <strong dir="ltr">{quote.totalMinor ? formatMinorExact(quote.totalMinor, currency, locale) : "—"}</strong>
            </p>
            <p className="client-verified">{w.quoteServerCalc}</p>
            <section className="provider-quote-notes">
              <article><h4>{w.quoteInclusions}</h4><ul>{lines(prefill.inclusions).map((item) => <li key={item}>{item}</li>)}</ul></article>
              <article><h4>{w.quoteExclusions}</h4><ul>{lines(prefill.exclusions).map((item) => <li key={item}>{item}</li>)}</ul></article>
              <article><h4>{w.quoteWarranty}</h4><p>{prefill.warranty}</p></article>
            </section>
          </article>
          <aside className="client-stack">
            <article className="client-card">
              <header><h3>{w.quoteSubmitChecklist}</h3></header>
              <ul className="client-feed">
                {checks.map((item) => (
                  <li key={item.label}><span className="client-status-chip" data-tone={item.ok ? "mint" : "peach"}>{item.ok ? "OK" : "—"}</span><span>{item.label}</span></li>
                ))}
              </ul>
              <p className="client-verified">{w.quoteReadyToSubmit}</p>
              {submitPanel}
              <div className="provider-workbench-actions">
                <Link href={editHref} className="client-ghost-link">{w.quoteBackToEdit}</Link>
              </div>
            </article>
          </aside>
        </section>
      )}
    </main>
  );
}
