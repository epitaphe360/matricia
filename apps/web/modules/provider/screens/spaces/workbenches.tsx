import Link from "next/link";
import {
  ArrowRight,
  Building2,
  Calendar,
  Check,
  ClipboardCheck,
  FileText,
  Lock,
  MessageSquare,
  Plus,
  Send,
  ShieldCheck,
  TriangleAlert,
} from "lucide-react";
import type { ReactNode } from "react";
import { formatMinor } from "@/modules/provider/data/billing/model";
import type { BillingDashboard } from "@/modules/provider/data/billing/model";
import type { ProviderMissionDashboard } from "@/modules/provider/data/missions/model";
import { consultationDocumentHref, type ConsultationPackDocument, type ProviderQuoteDashboard } from "@/modules/provider/data/quotes/model";
import { workbenchCopy } from "@/modules/provider/data/spaces/workbench-copy";
import { BillingPanel } from "@/modules/provider/screens/facturation/billing-panel";
import type { BillingMessages } from "@/modules/provider/screens/facturation/messages";
import type { MissionOption } from "@/modules/provider/screens/facturation/options";
import { QuotePanel } from "@/modules/provider/screens/devis/quote-panel";
import type { QuotePrefill } from "@/modules/provider/screens/devis/prefill";
import type { ProviderQuoteMessages } from "@/modules/provider/screens/devis/messages";
import { MissionsPanel } from "@/modules/provider/screens/missions/missions-panel";
import type { ProviderMissionMessages } from "@/modules/provider/screens/missions/messages";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

function Crumb({ href, children }: { href: string; children: ReactNode }) {
  return <Link href={href} className="client-text-link">{children}</Link>;
}

function ScopeNote({ locale, query }: { locale: Locale; query: string }) {
  const w = workbenchCopy(locale);
  return (
    <article className="client-card provider-scope-note" role="status">
      <Lock className="size-4" aria-hidden />
      <div>
        <strong>{w.outOfScope}</strong>
        <p>{w.outOfScopeLead}</p>
      </div>
      <Link href={`/${locale}/sous-traitant/consultations${query}`} className="client-ghost-link">
        {w.breadcrumbConsult}
        <ArrowRight className="size-4 rtl:rotate-180" aria-hidden />
      </Link>
    </article>
  );
}

export function ConsultationDetailWorkbench({
  locale,
  query,
  consultationId,
  invitation,
  quotePanel,
}: {
  locale: Locale;
  query: string;
  consultationId: string;
  invitation?: ProviderQuoteDashboard["invitations"][number] | null;
  quotePanel?: ReactNode;
}) {
  const w = workbenchCopy(locale);
  const pack = invitation?.pack;
  const title = invitation?.description ?? w.consultDetailTitle;
  const deadline = invitation
    ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short" }).format(new Date(invitation.deadline))
    : "—";
  const messagesHref = invitation
    ? `/${locale}/sous-traitant/messages${query}${query.includes("?") ? "&" : "?"}rfq=${encodeURIComponent(invitation.rfqId)}`
    : `/${locale}/sous-traitant/messages${query}`;
  const quoteHref = `/${locale}/sous-traitant/devis/${invitation?.quote?.id ?? invitation?.id ?? consultationId}${query}`;
  const objective = pack?.objective ?? invitation?.description ?? w.consultDetailLead;
  const scopeItems = pack?.scope.length
    ? pack.scope
    : invitation?.regionCode && invitation.regionCode !== "—"
      ? [invitation.regionCode]
      : [];
  const deliverables = pack?.deliverables ?? [];
  const constraints = pack?.constraints ?? [];
  const documents: ConsultationPackDocument[] = pack?.documents ?? [];
  return (
    <main className="client-page provider-workbench">
      <p className="provider-breadcrumb"><Crumb href={`/${locale}/sous-traitant/consultations${query}`}>{w.breadcrumbConsult}</Crumb><span aria-hidden>›</span><span>{w.breadcrumbConsultDetail}</span></p>
      <header className="provider-workbench-hero">
        <div>
          <p className="client-space-label" dir="ltr">#{consultationId.slice(0, 12)}</p>
          <h2>{title}</h2>
          <p>{w.consultDetailLead}</p>
        </div>
        <div className="provider-workbench-meta">
          <span className="client-status-chip" data-tone="mint">{w.consultOnInvite}</span>
          <span className="provider-deadline"><Calendar className="size-4" aria-hidden />{w.consultDeadlineLabel} · {deadline}</span>
        </div>
      </header>
      <nav className="client-tabs" aria-label={w.consultDetailTitle}>
        <a href="#consult-overview" aria-current="page">{w.consultOverview}</a>
        <a href="#consult-docs">{w.consultDocs}{documents.length ? ` (${documents.length})` : ""}</a>
        <a href={messagesHref}>{w.consultExchanges}</a>
        <a href={quoteHref}>{w.consultMyQuote}</a>
      </nav>
      <section className="provider-workbench-grid" id="consult-overview">
        <article className="client-card">
          <header><h3>{w.consultObjectiveTitle}</h3></header>
          <p>{objective}</p>
        </article>
        <article className="client-card">
          <header><h3>{w.consultScopeTitle}</h3></header>
          {scopeItems.length === 0 ? <p>{w.consultListEmpty}</p> : (
            <ul className="client-feed">
              {scopeItems.map((item) => <li key={item}><span>{item}</span></li>)}
            </ul>
          )}
          <p className="client-access-note">{w.consultScopeLimit}</p>
        </article>
        <article className="client-card">
          <header><h3>{w.consultDeliverablesTitle}</h3></header>
          {deliverables.length === 0 ? <p>{w.consultListEmpty}</p> : (
            <ul className="client-feed">
              {deliverables.map((item) => <li key={item}><span>{item}</span></li>)}
            </ul>
          )}
        </article>
        <article className="client-card">
          <header><h3>{w.consultConstraintsTitle}</h3></header>
          {constraints.length === 0 ? <p>{w.consultListEmpty}</p> : (
            <ul className="client-feed">
              {constraints.map((item) => <li key={item}><span>{item}</span></li>)}
            </ul>
          )}
        </article>
        <article className="client-card" id="consult-docs">
          <header><h3>{w.consultDocsTitle}{documents.length ? ` (${documents.length})` : ""}</h3></header>
          {documents.length === 0 ? <p>{w.consultDocsEmpty}</p> : (
            <ul className="client-feed">
              {documents.map((doc) => {
                const href = doc.id && invitation ? consultationDocumentHref(invitation.id, doc.id) : null;
                return (
                  <li key={doc.id ?? doc.title}>
                    <FileText className="size-4" aria-hidden />
                    <span><strong>{doc.title}</strong><small>{[doc.type, doc.size].filter(Boolean).join(" · ")}</small></span>
                    {href ? <a href={href} className="client-feed-download" download aria-label={`${w.download} — ${doc.title}`}>{w.download}</a> : null}
                  </li>
                );
              })}
            </ul>
          )}
        </article>
        <article className="client-card provider-fit">
          <header><h3>{w.consultFitTitle}</h3></header>
          <p>{w.consultFitLead}</p>
          <ul className="client-feed">
            <li><Check className="size-4" aria-hidden /><span>{w.consultFitService}</span></li>
            <li><Check className="size-4" aria-hidden /><span>{w.consultFitZone}</span></li>
            <li><Check className="size-4" aria-hidden /><span>{w.consultFitDocs}</span></li>
            <li><Check className="size-4" aria-hidden /><span>{w.consultFitRule}</span></li>
          </ul>
        </article>
        <aside className="client-stack">
          <article className="client-card">
            <p className="client-status">{w.consultInviteOpen}</p>
            {quotePanel ? (
              <div className="provider-workbench-actions">
                <a href="#invitation-decision" className="client-cta">{w.consultAccept}</a>
                <a href="#invitation-decision" className="client-ghost-link">{w.consultDecline}</a>
              </div>
            ) : null}
            <Link href={quoteHref} className="client-cta">{w.consultStartQuote} →</Link>
            <p className="client-access-note">{w.consultNoCompetitor}</p>
          </article>
          <article className="client-card">
            <header><h3>{w.consultCalendar}</h3></header>
            <ol className="client-journey">
              <li data-state="done"><span><Check className="size-4" aria-hidden /></span><small>{w.consultPublished}</small></li>
              <li data-state="current"><span><Calendar className="size-4" aria-hidden /></span><small>{w.consultDeadlineLabel} · {deadline}</small></li>
            </ol>
          </article>
          <article className="client-card">
            <header><h3>{w.consultAskTitle}</h3></header>
            <p>{w.consultAskLead}</p>
            <Link href={messagesHref} className="client-cta">{w.consultSend}</Link>
          </article>
        </aside>
      </section>
      {quotePanel ? <div id="invitation-decision">{quotePanel}</div> : null}
    </main>
  );
}

export function QuoteMultilineWorkbench({
  locale,
  query,
  quoteId,
  invitation,
  quotePanel,
  prefill,
}: {
  locale: Locale;
  query: string;
  quoteId: string;
  invitation?: ProviderQuoteDashboard["invitations"][number] | null;
  quotePanel?: ReactNode;
  prefill?: QuotePrefill;
}) {
  const w = workbenchCopy(locale);
  const currency = invitation?.currency ?? invitation?.quote?.currency ?? null;
  const subtotal = invitation?.quote?.subtotalMinor && currency ? formatMinor(invitation.quote.subtotalMinor, currency, locale) : "—";
  const tax = invitation?.quote?.taxMinor && currency ? formatMinor(invitation.quote.taxMinor, currency, locale) : "—";
  const total = invitation?.quote?.totalMinor && currency ? formatMinor(invitation.quote.totalMinor, currency, locale) : "—";
  const createdOn = invitation?.deadline
    ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(invitation.deadline))
    : "—";
  const validity = prefill?.validUntil
    ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(prefill.validUntil))
    : "—";
  return (
    <main className="client-page provider-workbench">
      <p className="provider-breadcrumb"><Crumb href={`/${locale}/sous-traitant/devis${query}`}>{w.breadcrumbQuotes}</Crumb><span aria-hidden>›</span><span>{w.breadcrumbQuoteCreate}</span></p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.quoteCreateTitle}</h2>
          <p>{w.quoteCreateLead}</p>
        </div>
        <div className="provider-workbench-meta">
          <span className="client-status-chip" data-tone="violet">{invitation?.quote?.status ?? w.quoteDraftStatus}</span>
        </div>
      </header>
      <section className="provider-quote-meta">
        <article className="client-card"><small>{w.quoteConsultation}</small><strong>{invitation?.description ?? w.quoteCreateTitle}</strong></article>
        <article className="client-card"><small>{w.quoteClient}</small><strong>{w.quoteClientMasked}</strong><p>{w.quoteClientHiddenLead}</p></article>
        <article className="client-card"><small>{w.quoteCreatedOn}</small><strong dir="ltr">{createdOn}</strong></article>
        <article className="client-card"><small>{w.quoteValidity}</small><strong>{validity}</strong></article>
      </section>
      <section className="provider-workbench-grid provider-quote-grid">
        <article className="client-card">
          <header className="client-priority-head">
            <h3>{w.quoteLines}</h3>
            {invitation ? <Link href={`/${locale}/sous-traitant/devis/${invitation.quote?.id ?? invitation.id}/revision${query}`} className="client-ghost-link"><Plus className="size-4" aria-hidden />{w.quoteAddLine}</Link> : null}
          </header>
          {quotePanel ?? (
            <p role="status">{w.consultListEmpty}</p>
          )}
          {prefill ? (
          <section className="provider-quote-notes">
            {prefill.inclusions ? <article><h4>{w.quoteInclusions}</h4><p>{prefill.inclusions}</p></article> : null}
            {prefill.exclusions ? <article><h4>{w.quoteExclusions}</h4><p>{prefill.exclusions}</p></article> : null}
            {prefill.warranty ? <article><h4>{w.quoteWarranty}</h4><p>{prefill.warranty}</p></article> : null}
          </section>
          ) : null}
        </article>
        <aside className="client-stack">
          <article className="client-card">
            <header><h3>{w.quoteRecap}</h3></header>
            <dl className="provider-money">
              <div><dt>{w.quoteSubtotal}</dt><dd dir="ltr">{subtotal}</dd></div>
              <div><dt>{w.quoteTax}</dt><dd dir="ltr">{tax}</dd></div>
              <div><dt>{w.quoteTotal}</dt><dd dir="ltr">{total}</dd></div>
            </dl>
            <p className="client-verified">{w.quoteServerCalc}</p>
            <p className="client-access-note">{w.quoteNoPeerAmounts}</p>
          </article>
          <article className="client-card">
            <header><h3>{w.quoteChecks}</h3></header>
            <ul className="client-feed">
              <li><Check className="size-4" aria-hidden /><span>{w.quoteCheckLines}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.quoteCheckValid}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.quoteCheckDate}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.quoteCheckAmounts}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.quoteNoBlocker}</span></li>
            </ul>
            <div className="provider-workbench-actions">
              <Link href={`/${locale}/sous-traitant/devis${query}`} className="client-ghost-link">{w.quoteBackToList}</Link>
              {invitation?.quote?.id ? <Link href={`/${locale}/sous-traitant/devis/${invitation.quote.id}/apercu${query}`} className="client-ghost-link">{w.quotePreview}</Link> : null}
              {invitation ? <Link href={`/${locale}/sous-traitant/devis/${invitation.quote?.id ?? invitation.id}/revision${query}`} className="client-cta">{w.quoteContinue} →</Link> : null}
            </div>
          </article>
        </aside>
      </section>
    </main>
  );
}

export function QuoteRevisionWorkbench({
  locale,
  query,
  quoteId,
  invitation,
  quotePanel,
}: {
  locale: Locale;
  query: string;
  quoteId: string;
  invitation?: ProviderQuoteDashboard["invitations"][number] | null;
  quotePanel?: ReactNode;
  prefill?: QuotePrefill;
}) {
  const w = workbenchCopy(locale);
  const currency = invitation?.currency ?? invitation?.quote?.currency ?? null;
  const total = invitation?.quote?.totalMinor && currency ? formatMinor(invitation.quote.totalMinor, currency, locale) : "—";
  return (
    <main className="client-page provider-workbench">
      <p className="provider-breadcrumb"><Crumb href={`/${locale}/sous-traitant/devis${query}`}>{w.quoteBackToList}</Crumb></p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.quoteReviseTitle}</h2>
          <p>{w.quoteReviseLead}</p>
        </div>
        <Link href={`/${locale}/sous-traitant/consultations/${invitation?.id ?? quoteId}${query}`} className="client-ghost-link">{w.quoteSeeConsult}</Link>
      </header>
      <section className="provider-workbench-grid">
        <article className="client-card">
          <header><h3>{w.quoteVersionHistory}</h3></header>
          <ol className="client-journey">
            <li data-state="done"><span>v{Math.max(1, (invitation?.quote?.versionNumber ?? 1) - 1)}</span><small>{w.quoteImmutable}</small></li>
            <li data-state="current"><span>v{invitation?.quote?.versionNumber ?? 1}</span><small>{w.quoteEditing}</small></li>
          </ol>
          <p className="client-access-note">{w.quoteReviseNotice}</p>
          {quotePanel}
          <p className="client-verified">{w.quoteDoubleClick}</p>
        </article>
        <aside className="client-stack">
          <article className="client-card">
            <header><h3>{w.quoteChangeSummary}</h3></header>
            <ul className="client-feed">
              <li><span><strong>{w.quoteModified}</strong><small>{w.quoteTotalsOk}</small></span></li>
              <li><span><strong>{w.quoteUnchanged}</strong><small>{w.quoteScopeOk}</small></span></li>
            </ul>
          </article>
          <article className="client-card">
            <header><h3>{w.quoteSubmitChecklist}</h3></header>
            <ul className="client-feed">
              {[w.quoteScopeOk, w.quoteTotalsOk, w.quoteTaxOk, w.quoteValidityOk, w.quoteAttachmentsOk, w.quoteDeadlineOk].map((item) => (
                <li key={item}><Check className="size-4" aria-hidden /><span>{item}</span></li>
              ))}
            </ul>
            <p className="provider-money"><strong dir="ltr">{total}</strong></p>
            <p className="client-access-note">{w.quoteNoPeerAmounts}</p>
            {invitation?.quote?.status === "SUBMITTED" ? <p className="client-verified">{w.quoteSubmitSuccess}</p> : null}
          </article>
        </aside>
      </section>
    </main>
  );
}

export function MissionDeliveryWorkbench({
  locale,
  query,
  missionId,
  mission,
  missionsPanel,
}: {
  locale: Locale;
  query: string;
  missionId: string;
  mission?: ProviderMissionDashboard["missions"][number] | null;
  missionsPanel?: ReactNode;
}) {
  const w = workbenchCopy(locale);
  const title = mission
    ? (mission.deliverables[0]?.label || mission.milestones[0]?.title || mission.id.slice(0, 8))
    : w.missionDeliveryTitle;
  const steps = mission?.milestones.length
    ? mission.milestones.map((item) => ({
        id: item.id,
        title: item.title,
        state: ["DONE", "COMPLETED"].includes(item.status) ? "done" as const : item.status === "IN_PROGRESS" || item.status === "CURRENT" ? "current" as const : "todo" as const,
      }))
    : [];
  const history = mission?.deliverables.flatMap((item) => item.versions.map((version) => ({
    id: version.id,
    title: item.label,
    detail: `${version.proofScanStatus} · v${version.version}`,
  }))) ?? [];
  const messagesHref = `/${locale}/sous-traitant/messages${query}`;
  return (
    <main className="client-page provider-workbench">
      <p className="provider-breadcrumb"><Crumb href={`/${locale}/sous-traitant/missions${query}`}>{w.breadcrumbMissions}</Crumb><span aria-hidden>›</span><span dir="ltr">{missionId.slice(0, 12)}</span></p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.missionDeliveryTitle}</h2>
          <p>{w.missionDeliveryLead}</p>
          <p><strong>{title}</strong></p>
        </div>
        <div className="provider-workbench-meta">
          <span className="client-status-chip" data-tone="mint">{mission?.status ?? w.missionInProgress}</span>
          <Link href={`/${locale}/sous-traitant/missions${query}`} className="client-ghost-link">{w.missionBack}</Link>
        </div>
      </header>
      <section className="provider-workbench-grid">
        <article className="client-card">
          <header><h3>{w.missionMilestones}</h3></header>
          {steps.length === 0 ? <p role="status">{w.missionNoMilestones}</p> : (
          <ol className="client-journey">
            {steps.map((step, index) => (
              <li key={step.id} data-state={step.state}><span>{index + 1}</span><small>{step.title}</small></li>
            ))}
          </ol>
          )}
          <header><h3>{w.missionDeliverable}</h3></header>
          <p>{w.missionDeliverableHelp}</p>
          {missionsPanel ?? <p role="status">{w.missionNoFile}</p>}
          <div className="provider-workbench-actions">
            <Link href={messagesHref} className="client-ghost-link"><MessageSquare className="size-4" aria-hidden />{w.missionAskClarification}</Link>
          </div>
        </article>
        <aside className="client-stack">
          <article className="client-card">
            <header><h3>{w.missionClientAccess}</h3></header>
            <ul className="client-feed">
              <li><Check className="size-4" aria-hidden /><span>{w.missionAccessDeliverables}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.missionAccessMessages}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.missionAccessDocs}</span></li>
              <li><Check className="size-4" aria-hidden /><span>{w.missionAccessMilestones}</span></li>
            </ul>
          </article>
          <article className="client-card">
            <header><h3>{w.missionHistory}</h3></header>
            {history.length === 0 ? <p role="status">{w.missionNoHistory}</p> : (
            <ul className="client-feed">
              {history.map((item) => (
                <li key={item.id}><span className="client-feed-icon" data-tone="mint" /><span><strong>{item.title}</strong><small>{item.detail}</small></span></li>
              ))}
            </ul>
            )}
            <p className="client-access-note">{w.missionGoodToKnow}</p>
          </article>
        </aside>
      </section>
    </main>
  );
}

export function InvoiceSettlementWorkbench({
  locale,
  query,
  invoiceId,
  invoice,
  billingPanel,
}: {
  locale: Locale;
  query: string;
  invoiceId: string;
  invoice?: BillingDashboard["invoices"][number] | null;
  billingPanel?: ReactNode;
}) {
  const w = workbenchCopy(locale);
  const currency = invoice?.currency ?? null;
  const total = invoice && currency ? formatMinor(invoice.totalMinor, currency, locale) : "—";
  const paid = invoice && currency ? formatMinor(invoice.paidMinor, currency, locale) : "—";
  const outstanding = invoice && currency ? formatMinor(invoice.outstandingMinor, currency, locale) : "—";
  const settled = Boolean(invoice && invoice.outstandingMinor === "0" && invoice.paidMinor !== "0");
  const declared = Boolean(invoice && invoice.paidMinor !== "0");
  return (
    <main className="client-page provider-workbench">
      <p className="provider-breadcrumb"><Crumb href={`/${locale}/sous-traitant/facturation${query}`}>{w.breadcrumbBilling}</Crumb><span aria-hidden>›</span><span>{w.breadcrumbInvoice}</span></p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.invoiceTitle}</h2>
          <p>{w.invoiceLead}</p>
          <p dir="ltr"><strong>{invoice?.number ?? invoiceId.slice(0, 12)}</strong></p>
        </div>
        <span className="client-status-chip" data-tone={settled ? "mint" : "peach"}>{settled ? w.invoiceSettled : (invoice?.paymentStatus.replaceAll("_", " ") ?? "—")}</span>
      </header>
      <section className="provider-invoice-hero">
        <article className="client-card">
          <dl className="provider-money">
            <div><dt>{w.invoiceTtc}</dt><dd dir="ltr">{total}</dd></div>
            <div><dt>{w.invoiceStepDeclared}</dt><dd dir="ltr">{paid}</dd></div>
            <div><dt>{w.invoiceOutstanding}</dt><dd dir="ltr">{outstanding}</dd></div>
          </dl>
          {invoice ? null : <p role="status">{w.invoiceNoAmount}</p>}
        </article>
        <article className="client-card provider-blocker" data-scope="service">
          <TriangleAlert className="size-4" aria-hidden />
          <p>{w.invoicePaymentNotProof}</p>
        </article>
        <div className="provider-workbench-actions">
          <Link href={`/${locale}/sous-traitant/documents${query}`} className="client-cta">{w.invoiceAddProof}</Link>
          <Link href={`/${locale}/sous-traitant/messages${query}`} className="client-ghost-link">{w.invoiceReportGap}</Link>
        </div>
      </section>
      <section className="provider-workbench-grid">
        <article className="client-card">
          <header><h3>{w.invoiceRelatedDocs}</h3></header>
          <p role="status">{w.invoiceNoDocs}</p>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h3>{w.invoiceBilledDeliverables}</h3></header>
          <p role="status">{w.invoiceNoDeliverable}</p>
        </article>
        <article className="client-card">
          <header><h3>{w.invoiceFiscal}</h3></header>
          <ul className="client-feed">
            <li><span><strong>{w.invoiceCurrency}</strong><small>{invoice?.currency ?? "—"}</small></span></li>
            <li><span><strong>{w.invoiceTaxBase}</strong><small>{w.invoiceTaxBaseHt}</small></span></li>
          </ul>
        </article>
        <article className="client-card">
          <header><h3>{w.invoiceFollow}</h3></header>
          <ol className="client-journey">
            <li data-state={invoice ? "done" : "todo"}><span><ClipboardCheck className="size-4" aria-hidden /></span><small>{w.invoiceStepDraft}</small></li>
            <li data-state={invoice ? "done" : "todo"}><span><Send className="size-4" aria-hidden /></span><small>{w.invoiceStepSubmitted}</small></li>
            <li data-state={declared ? "done" : "todo"}><span><Check className="size-4" aria-hidden /></span><small>{w.invoiceStepDeclared}</small></li>
            <li data-state={settled ? "current" : "todo"}><span><Check className="size-4" aria-hidden /></span><small>{w.invoiceStepReconciled}</small></li>
          </ol>
        </article>
        <article className="client-card">
          <header><h3>{w.invoiceProofs}</h3></header>
          <p className="client-access-note">{w.invoiceReconcileNote}</p>
        </article>
      </section>
      {billingPanel}
    </main>
  );
}

export function MessagesNotificationsWorkbench({
  locale,
  query,
}: {
  locale: Locale;
  query: string;
  threadId?: string;
}) {
  const w = workbenchCopy(locale);
  return (
    <main className="client-page provider-workbench provider-messages">
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.messagesTitle}</h2>
          <p>{w.messagesLead}</p>
        </div>
      </header>
      <nav className="client-tabs" aria-label={w.messagesTitle}>
        <Link href={`/${locale}/sous-traitant/messages${query}`} aria-current="page">{w.messagesTab}</Link>
        <Link href={`/${locale}/notifications${query}`}>{w.notifTab}</Link>
      </nav>
      <section className="provider-messages-grid" id="messages">
        <article className="client-card">
          <p role="status">{w.notifEmpty}</p>
          <Link href={`/${locale}/sous-traitant/messages${query}`} className="client-cta">{w.messagesTab}</Link>
        </article>
        <aside className="client-stack" id="notifications">
          <article className="client-card">
            <header><h3>{w.notifTab}</h3></header>
            <p role="status">{w.notifEmpty}</p>
            <Link href={`/${locale}/notifications${query}`} className="client-text-link">{w.managePrefs}</Link>
          </article>
        </aside>
      </section>
    </main>
  );
}

export function CompanySecurityWorkbench({
  locale,
  query,
  organizationName,
  userEmail,
  mfaEnabled = null,
  sessions = [],
  members = [],
}: {
  locale: Locale;
  query: string;
  organizationName?: string | null;
  userEmail?: string | null;
  mfaEnabled?: boolean | null;
  sessions?: readonly { id: string; label: string; lastSeen: string; isCurrent: boolean }[];
  members?: readonly { id: string; name: string; role: string }[];
}) {
  const w = workbenchCopy(locale);
  const name = organizationName ?? (locale === "ar" ? "مؤسستكم" : "Votre entreprise");
  const mfaLabel = mfaEnabled === true ? w.mfaOn : mfaEnabled === false ? w.mfaOff : "—";
  return (
    <main className="client-page provider-workbench">
      <p className="provider-breadcrumb"><span>{w.companyTitle}</span><span aria-hidden>›</span><span>{w.tabSecurity}</span></p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.companyTitle}</h2>
          <p>{w.companyLead}</p>
        </div>
        <p className="client-verified"><ShieldCheck className="size-4" aria-hidden />{w.companySecure} — {w.companySecureLead}</p>
      </header>
      <nav className="client-tabs" aria-label={w.companyTitle}>
        <Link href={`/${locale}/organisation${query}`}>{w.tabProfile}</Link>
        <Link href={`/${locale}/organisation/roles${query}`}>{w.tabTeam}</Link>
        <Link href={`/${locale}/organisation/roles${query}`}>{w.tabRoles}</Link>
        <Link href={`/${locale}/organisation/roles${query}`}>{w.tabInvites}</Link>
        <Link href={`/${locale}/securite/compte${query}`} aria-current="page">{w.tabSecurity}</Link>
        <Link href={`/${locale}/securite/sessions${query}`}>{w.tabSessions}</Link>
        <Link href={`/${locale}/notifications${query}`}>{w.tabPrefs}</Link>
      </nav>
      <section className="provider-workbench-grid" id="securite">
        <article className="client-card" id="profil">
          <header className="client-priority-head">
            <h3>{w.companyIdentity}</h3>
            <Link href={`/${locale}/sous-traitant/entreprise/contrat${query}`} className="client-text-link">{locale === "ar" ? "عقد الشراكة" : "Contrat partenaire"}</Link>
          </header>
          <ul className="client-feed">
            <li><Building2 className="size-4" aria-hidden /><span><strong>{name}</strong></span></li>
            <li><span><strong>{w.companyLegalName}</strong><small>{name}</small></span></li>
            <li><span><strong>{w.companySector}</strong><small>—</small></span></li>
          </ul>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h3>{w.companyAccounting}</h3><Link href={`/${locale}/organisation${query}`} className="client-text-link">{w.companyEdit}</Link></header>
          <p dir="ltr">{userEmail ?? "—"}</p>
        </article>
        <article className="client-card" id="equipe">
          <header className="client-priority-head"><h3>{w.tabTeam}</h3><Link href={`/${locale}/organisation/roles${query}`} className="client-text-link">{w.modify}</Link></header>
          {members.length === 0 ? <p role="status">{w.sessionsEmpty}</p> : (
            <ul className="client-feed">
              {members.map((member) => (
                <li key={member.id}><span><strong>{member.name}</strong><small>{member.role}</small></span></li>
              ))}
            </ul>
          )}
          <p className="client-access-note">{w.companyNoOtherOrg}</p>
        </article>
        <article className="client-card">
          <header><h3>{w.authSecurity}</h3></header>
          <p>{w.authSecurityLead}</p>
          <ul className="client-feed">
            <li><Lock className="size-4" aria-hidden /><span><strong>{w.mfaTitle}</strong><small>{w.mfaLead}</small></span><em>{mfaLabel}</em></li>
            <li><span><strong>{w.verifyMethods}</strong><small>{w.verifyApp}</small></span><Link href={`/${locale}/securite/compte${query}`} className="client-text-link">{w.modify}</Link></li>
          </ul>
        </article>
        <article className="client-card" id="sessions">
          <header className="client-priority-head"><h3>{w.activeSessions}</h3><Link href={`/${locale}/securite/sessions${query}`} className="client-text-link">{w.seeHistory}</Link></header>
          {sessions.length === 0 ? <p role="status">{w.sessionsEmpty}</p> : (
          <div className="client-table-wrap">
            <table className="client-space-table">
              <thead><tr><th>{w.sessionDevice}</th><th>{w.sessionLast}</th><th>{w.sessionStatus}</th></tr></thead>
              <tbody>
                {sessions.map((session) => (
                  <tr key={session.id}>
                    <td>{session.label}</td>
                    <td>{session.lastSeen}</td>
                    <td><span className="client-status-chip" data-tone={session.isCurrent ? "mint" : "sky"}>{session.isCurrent ? w.sessionCurrent : w.sessionActive}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          )}
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h3>{w.securityHistory}</h3><Link href={`/${locale}/securite/compte${query}`} className="client-text-link">{w.seeHistory}</Link></header>
          <p role="status">{w.historyEmpty}</p>
        </article>
      </section>
    </main>
  );
}

export function ProviderOutOfScope({ locale, query }: { locale: Locale; query: string }) {
  return (
    <main className="client-page">
      <ScopeNote locale={locale} query={query} />
    </main>
  );
}

export function ProviderLiveQuotePanel(props: {
  dashboard: ProviderQuoteDashboard;
  locale: Locale;
  m: ProviderQuoteMessages;
  identities: Record<string, { decision: string; revision: string; submit: string; correlation: string }>;
  prefills?: Record<string, QuotePrefill>;
}) {
  return <section className="provider-live-ops"><QuotePanel {...props} /></section>;
}

export function ProviderLiveMissionsPanel(props: {
  dashboard: ProviderMissionDashboard;
  locale: Locale;
  messages: ProviderMissionMessages;
}) {
  return <section className="provider-live-ops"><MissionsPanel {...props} /></section>;
}

export function ProviderLiveBillingPanel(props: {
  dashboard: BillingDashboard;
  missions: MissionOption[];
  locale: Locale;
  m: BillingMessages;
  keys: string[];
}) {
  return <section className="provider-live-ops"><BillingPanel {...props} /></section>;
}
