import Link from "next/link";
import {
  ArrowRight,
  Box,
  Building2,
  Calendar,
  Check,
  ClipboardCheck,
  FileText,
  FolderOpen,
  Lock,
  MapPin,
  MessageSquare,
  Plus,
  Send,
  Settings2,
  ShieldCheck,
  Target,
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

function CardHead({ icon, children }: { icon: ReactNode; children: ReactNode }) {
  return (
    <header className="provider-card-head">
      <span className="provider-card-icon" aria-hidden>{icon}</span>
      <h3>{children}</h3>
    </header>
  );
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

function formatMedium(locale: Locale, value: string, withTime = false) {
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", {
    dateStyle: "medium",
    ...(withTime ? { timeStyle: "short" as const } : {}),
  }).format(new Date(value));
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
  const deadline = invitation ? formatMedium(locale, invitation.deadline, true) : "—";
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
  const region = invitation?.regionCode && invitation.regionCode !== "—" ? invitation.regionCode : w.consultLocationFallback;
  return (
    <main className="client-page provider-workbench provider-consult-detail">
      <p className="provider-breadcrumb">
        <Crumb href={`/${locale}/sous-traitant/consultations${query}`}>{w.breadcrumbConsult}</Crumb>
        <span aria-hidden>›</span>
        <span>{w.breadcrumbConsultDetail}</span>
      </p>
      <header className="provider-workbench-hero">
        <div>
          <p className="client-space-label" dir="ltr">#{consultationId.slice(0, 12)}</p>
          <h2>{title}</h2>
          <p>{w.consultDetailLead}</p>
          <div className="provider-chip-row">
            {invitation?.regionCode && invitation.regionCode !== "—" ? (
              <span className="provider-meta-chip"><Building2 className="size-3.5" aria-hidden />{invitation.regionCode}</span>
            ) : null}
            <span className="provider-meta-chip"><MapPin className="size-3.5" aria-hidden />{region}</span>
            <span className="client-status-chip" data-tone="mint">{w.consultOnInvite}</span>
          </div>
        </div>
        <div className="provider-workbench-meta">
          <span className="provider-deadline-box">
            <Calendar className="size-4" aria-hidden />
            <span>
              <strong>{w.consultDeadlineLabel}</strong>
              <em dir="ltr">{deadline}</em>
            </span>
          </span>
        </div>
      </header>
      <nav className="client-tabs" aria-label={w.consultDetailTitle}>
        <a href="#consult-overview" aria-current="page">{w.consultOverview}</a>
        <a href="#consult-docs">{w.consultDocs}{documents.length ? ` (${documents.length})` : ""}</a>
        <a href={messagesHref}>{w.consultExchanges}</a>
        <a href={quoteHref}>{w.consultMyQuote}</a>
      </nav>
      <section className="provider-workbench-layout" id="consult-overview">
        <div className="provider-workbench-main">
          <div className="provider-consult-cards">
            <article className="client-card">
              <CardHead icon={<Target className="size-4" />}>{w.consultObjectiveTitle}</CardHead>
              <p>{objective}</p>
            </article>
            <article className="client-card">
              <CardHead icon={<Box className="size-4" />}>{w.consultScopeTitle}</CardHead>
              {scopeItems.length === 0 ? <p>{w.consultListEmpty}</p> : (
                <ul className="client-feed">
                  {scopeItems.map((item) => <li key={item}><span>{item}</span></li>)}
                </ul>
              )}
              <p className="client-access-note">{w.consultScopeLimit}</p>
            </article>
            <article className="client-card">
              <CardHead icon={<ClipboardCheck className="size-4" />}>{w.consultDeliverablesTitle}</CardHead>
              {deliverables.length === 0 ? <p>{w.consultListEmpty}</p> : (
                <ul className="client-feed">
                  {deliverables.map((item) => <li key={item}><span>{item}</span></li>)}
                </ul>
              )}
            </article>
            <article className="client-card">
              <CardHead icon={<TriangleAlert className="size-4" />}>{w.consultConstraintsTitle}</CardHead>
              {constraints.length === 0 ? <p>{w.consultListEmpty}</p> : (
                <ul className="client-feed">
                  {constraints.map((item) => <li key={item}><span>{item}</span></li>)}
                </ul>
              )}
            </article>
            <article className="client-card" id="consult-docs">
              <CardHead icon={<FolderOpen className="size-4" />}>{w.consultDocsTitle}{documents.length ? ` (${documents.length})` : ""}</CardHead>
              {documents.length === 0 ? <p>{w.consultDocsEmpty}</p> : (
                <ul className="client-feed provider-doc-list">
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
              <CardHead icon={<Settings2 className="size-4" />}>{w.consultFitTitle}</CardHead>
              <p>{w.consultFitLead}</p>
              <ul className="client-feed">
                <li><Check className="size-4" aria-hidden /><span>{w.consultFitService}</span></li>
                <li><Check className="size-4" aria-hidden /><span>{w.consultFitZone}</span></li>
                <li><Check className="size-4" aria-hidden /><span>{w.consultFitDocs}</span></li>
                <li><Check className="size-4" aria-hidden /><span>{w.consultFitRule}</span></li>
              </ul>
            </article>
          </div>
        </div>
        <aside className="provider-workbench-rail client-stack">
          <article className="client-card provider-invite-banner">
            <p className="client-status"><strong>{w.consultInProgress}</strong> — {w.consultInviteOpen}</p>
            {quotePanel ? (
              <div className="provider-workbench-actions provider-workbench-actions-stack">
                <a href="#invitation-decision" className="client-cta"><Check className="size-4" aria-hidden />{w.consultAccept}</a>
                <a href="#invitation-decision" className="client-ghost-link">{w.consultDecline}</a>
              </div>
            ) : null}
            <Link href={quoteHref} className="client-cta provider-cta-soft">{w.consultStartQuote}<ArrowRight className="size-4 rtl:rotate-180" aria-hidden /></Link>
            <p className="client-access-note">{w.consultNoCompetitor}</p>
          </article>
          <article className="client-card">
            <header><h3>{w.consultCalendar}</h3></header>
            <ol className="client-journey provider-timeline">
              <li data-state="done"><span><Check className="size-4" aria-hidden /></span><small>{w.consultPublished}</small></li>
              <li data-state="done"><span><Check className="size-4" aria-hidden /></span><small>{w.consultQuestionsDue}</small></li>
              <li data-state="current"><span><Calendar className="size-4" aria-hidden /></span><small>{w.consultQuoteDue}<em dir="ltr">{deadline}</em></small></li>
              <li data-state="todo"><span /><small>{w.consultAnalysis}</small></li>
              <li data-state="todo"><span /><small>{w.consultDecision}</small></li>
            </ol>
          </article>
          <article className="client-card">
            <header><h3>{w.consultAskTitle}</h3></header>
            <p>{w.consultAskLead}</p>
            <Link href={messagesHref} className="client-cta"><Send className="size-4" aria-hidden />{w.consultSend}</Link>
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
  const createdOn = invitation?.deadline ? formatMedium(locale, invitation.deadline) : "—";
  const validity = prefill?.validUntil ? formatMedium(locale, prefill.validUntil) : "—";
  return (
    <main className="client-page provider-workbench provider-quote-multiline">
      <p className="provider-breadcrumb">
        <Crumb href={`/${locale}/sous-traitant/devis${query}`}>{w.breadcrumbQuotes}</Crumb>
        <span aria-hidden>›</span>
        <span>{w.breadcrumbQuoteCreate}</span>
      </p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.quoteCreateTitle}</h2>
          <p>{w.quoteCreateLead}</p>
        </div>
        <div className="provider-workbench-meta">
          <span className="provider-autosave"><FileText className="size-4" aria-hidden />{w.quoteDraftSaved}</span>
          <span className="client-status-chip" data-tone="mint">{invitation?.quote?.status ?? w.quoteDraftStatus}</span>
        </div>
      </header>
      <section className="provider-quote-meta client-card">
        <div><small>{w.quoteConsultation}</small><strong>{invitation?.description ?? w.quoteCreateTitle}</strong></div>
        <div><small>{w.quoteClient}</small><strong>{w.quoteClientMasked}</strong><p>{w.quoteClientHiddenLead}</p></div>
        <div><small>{w.quoteCreatedOn}</small><strong dir="ltr">{createdOn}</strong></div>
        <div><small>{w.quoteValidity}</small><strong>{validity}</strong></div>
      </section>
      <section className="provider-workbench-layout">
        <div className="provider-workbench-main">
          <article className="client-card">
            <header className="client-priority-head">
              <h3>{w.quoteLines}</h3>
              {invitation ? (
                <Link href={`/${locale}/sous-traitant/devis/${invitation.quote?.id ?? invitation.id}/revision${query}`} className="client-ghost-link">
                  <Plus className="size-4" aria-hidden />{w.quoteAddLine}
                </Link>
              ) : null}
            </header>
            {quotePanel ?? <p role="status">{w.consultListEmpty}</p>}
            {prefill ? (
              <section className="provider-quote-notes">
                {prefill.inclusions ? <article><h4>{w.quoteInclusions}</h4><p>{prefill.inclusions}</p></article> : null}
                {prefill.exclusions ? <article><h4>{w.quoteExclusions}</h4><p>{prefill.exclusions}</p></article> : null}
                {prefill.warranty ? <article><h4>{w.quoteWarranty}</h4><p>{prefill.warranty}</p></article> : null}
              </section>
            ) : null}
          </article>
        </div>
        <aside className="provider-workbench-rail client-stack">
          <article className="client-card">
            <header><h3>{w.quoteRecap}</h3></header>
            <dl className="provider-money">
              <div><dt>{w.quoteSubtotal}</dt><dd dir="ltr">{subtotal}</dd></div>
              <div><dt>{w.quoteTax}</dt><dd dir="ltr">{tax}</dd></div>
              <div className="provider-money-total"><dt>{w.quoteTotal}</dt><dd dir="ltr">{total}</dd></div>
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
              <Link href={`/${locale}/sous-traitant/devis${query}`} className="client-ghost-link">{w.quoteSaveDraft}</Link>
              {invitation?.quote?.id ? <Link href={`/${locale}/sous-traitant/devis/${invitation.quote.id}/apercu${query}`} className="client-ghost-link">{w.quotePreview}</Link> : null}
              {invitation ? <Link href={`/${locale}/sous-traitant/devis/${invitation.quote?.id ?? invitation.id}/revision${query}`} className="client-cta">{w.quoteContinue}<ArrowRight className="size-4 rtl:rotate-180" aria-hidden /></Link> : null}
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
  const version = invitation?.quote?.versionNumber ?? 1;
  return (
    <main className="client-page provider-workbench provider-quote-revision">
      <p className="provider-breadcrumb">
        <Crumb href={`/${locale}/sous-traitant/devis${query}`}>{w.quoteBackToList}</Crumb>
      </p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.quoteReviseTitle}</h2>
          <p>{w.quoteReviseLead}</p>
        </div>
        <article className="provider-consult-summary client-card">
          <p><strong>{invitation?.description ?? w.quoteCreateTitle}</strong></p>
          <p dir="ltr">{invitation?.id ? `${locale === "ar" ? "مرجع" : "Réf."} ${invitation.id.slice(0, 8)}` : null}</p>
          <Link href={`/${locale}/sous-traitant/consultations/${invitation?.id ?? quoteId}${query}`} className="client-ghost-link">{w.quoteSeeConsult}<ArrowRight className="size-4 rtl:rotate-180" aria-hidden /></Link>
        </article>
      </header>
      <section className="provider-workbench-layout">
        <div className="provider-workbench-main">
          <article className="client-card">
            <header><h3>{w.quoteVersionHistory}</h3></header>
            <ol className="client-journey provider-version-rail">
              <li data-state="done"><span>v{Math.max(1, version - 1)}</span><small>{w.quoteImmutable}</small></li>
              <li data-state="current"><span>v{version}</span><small>{w.quoteEditing}</small></li>
            </ol>
            <p className="client-access-note">{w.quoteReviseNotice}</p>
            {quotePanel}
            <p className="client-verified">{w.quoteDoubleClick}</p>
          </article>
        </div>
        <aside className="provider-workbench-rail client-stack">
          <article className="client-card">
            <header><h3>{w.quoteChangeSummary}</h3></header>
            <ul className="client-feed provider-change-legend">
              <li data-change="added"><span><strong>{w.quoteAdded}</strong></span></li>
              <li data-change="modified"><span><strong>{w.quoteModified}</strong><small>{w.quoteTotalsOk}</small></span></li>
              <li data-change="unchanged"><span><strong>{w.quoteUnchanged}</strong><small>{w.quoteScopeOk}</small></span></li>
            </ul>
          </article>
          <article className="client-card">
            <header><h3>{w.quoteSubmitChecklist}</h3></header>
            <ul className="client-feed">
              {[w.quoteScopeOk, w.quoteTotalsOk, w.quoteTaxOk, w.quoteValidityOk, w.quoteAttachmentsOk, w.quoteDeadlineOk].map((item) => (
                <li key={item}><Check className="size-4" aria-hidden /><span>{item}</span></li>
              ))}
            </ul>
            <p className="provider-money-total"><strong dir="ltr">{total}</strong></p>
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
        due: item.dueAt ? formatMedium(locale, item.dueAt) : null,
        state: ["DONE", "COMPLETED"].includes(item.status) ? "done" as const : item.status === "IN_PROGRESS" || item.status === "CURRENT" ? "current" as const : "todo" as const,
      }))
    : [];
  const history = mission?.deliverables.flatMap((item) => item.versions.map((version) => ({
    id: version.id,
    title: item.label,
    detail: `${version.proofScanStatus} · v${version.version}`,
  }))) ?? [];
  const messagesHref = `/${locale}/sous-traitant/messages${query}`;
  const current = steps.find((step) => step.state === "current") ?? steps[0];
  return (
    <main className="client-page provider-workbench provider-mission-delivery">
      <p className="provider-breadcrumb">
        <Crumb href={`/${locale}/sous-traitant/missions${query}`}>{w.breadcrumbMissions}</Crumb>
        <span aria-hidden>›</span>
        <span dir="ltr">{missionId.slice(0, 12)}</span>
      </p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.missionDeliveryTitle}</h2>
          <p>{w.missionDeliveryLead}</p>
        </div>
        <Link href={`/${locale}/sous-traitant/missions${query}`} className="client-ghost-link">{w.missionBack}</Link>
      </header>
      <article className="client-card provider-mission-overview">
        <div>
          <p className="client-space-label" dir="ltr">{missionId.slice(0, 12)}</p>
          <h3>{title}</h3>
          <div className="provider-chip-row">
            <span className="client-status-chip" data-tone="mint">{mission?.status ?? w.missionInProgress}</span>
            <span className="provider-meta-chip">{w.missionContractSigned}</span>
          </div>
        </div>
        <div>
          <h4>{w.missionClientAccess}</h4>
          <ul className="client-feed provider-access-checks">
            <li><Check className="size-4" aria-hidden /><span>{w.missionAccessDeliverables}</span></li>
            <li><Check className="size-4" aria-hidden /><span>{w.missionAccessMessages}</span></li>
            <li><Check className="size-4" aria-hidden /><span>{w.missionAccessDocs}</span></li>
            <li><Check className="size-4" aria-hidden /><span>{w.missionAccessMilestones}</span></li>
          </ul>
        </div>
      </article>
      <section className="client-card">
        <header><h3>{w.missionMilestones}</h3></header>
        {steps.length === 0 ? <p role="status">{w.missionNoMilestones}</p> : (
          <ol className="provider-milestone-rail">
            {steps.map((step, index) => (
              <li key={step.id} data-state={step.state}>
                <span>{index + 1}</span>
                <strong>{step.title}</strong>
                <small>{step.due ?? (step.state === "done" ? "—" : "—")}</small>
              </li>
            ))}
          </ol>
        )}
      </section>
      <section className="provider-workbench-layout">
        <div className="provider-workbench-main">
          <article className="client-card">
            <header className="client-priority-head">
              <h3>{current ? current.title : w.missionDeliverable}</h3>
              {current?.state === "current" ? <span className="client-status-chip" data-tone="sky">{w.missionInProgress}</span> : null}
            </header>
            <p>{w.missionDeliverableHelp}</p>
            {missionsPanel ?? <p role="status">{w.missionNoFile}</p>}
            <div className="provider-workbench-actions">
              <Link href={messagesHref} className="client-ghost-link"><MessageSquare className="size-4" aria-hidden />{w.missionAskClarification}</Link>
            </div>
          </article>
        </div>
        <aside className="provider-workbench-rail client-stack">
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
    <main className="client-page provider-workbench provider-invoice-settlement">
      <p className="provider-breadcrumb">
        <Crumb href={`/${locale}/sous-traitant/facturation${query}`}>{w.breadcrumbBilling}</Crumb>
        <span aria-hidden>›</span>
        <span>{w.breadcrumbInvoice}</span>
      </p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.invoiceTitle}</h2>
          <p>{w.invoiceLead}</p>
        </div>
      </header>
      <section className="provider-invoice-top">
        <article className="client-card provider-invoice-summary">
          <header className="client-priority-head">
            <div>
              <p className="client-space-label" dir="ltr">{invoice?.number ?? invoiceId.slice(0, 12)}</p>
              <span className="client-status-chip" data-tone={settled ? "mint" : "peach"}>{settled ? w.invoiceSettled : (invoice?.paymentStatus.replaceAll("_", " ") ?? "—")}</span>
            </div>
          </header>
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
          <div className="provider-workbench-actions">
            <Link href={`/${locale}/sous-traitant/documents${query}`} className="client-cta">{w.invoiceAddProof}</Link>
            <Link href={`/${locale}/sous-traitant/messages${query}`} className="client-ghost-link">{w.invoiceReportGap}</Link>
          </div>
        </article>
      </section>
      <section className="provider-invoice-middle">
        <article className="client-card">
          <header><h3>{w.invoiceRelatedDocs}</h3></header>
          <p role="status">{w.invoiceNoDocs}</p>
        </article>
        <article className="client-card">
          <header className="client-priority-head">
            <h3>{w.invoiceBilledDeliverables}</h3>
            <span className="client-status-chip" data-tone="mint">{w.invoiceAllAccepted}</span>
          </header>
          <p role="status">{w.invoiceNoDeliverable}</p>
        </article>
        <article className="client-card">
          <CardHead icon={<Settings2 className="size-4" />}>{w.invoiceFiscal}</CardHead>
          <ul className="client-feed">
            <li><span><strong>{w.invoiceCurrency}</strong><small>{invoice?.currency ? w.invoiceCurrencyMad : "—"}</small></span></li>
            <li><span><strong>{w.invoiceTaxBase}</strong><small>{w.invoiceTaxBaseHt}</small></span></li>
            <li><span><strong>{w.invoiceTaxRegime}</strong><small>{w.invoiceTaxNormal}</small></span></li>
          </ul>
        </article>
      </section>
      <section className="provider-invoice-bottom">
        <article className="client-card">
          <header><h3>{w.invoiceFollow}</h3></header>
          <ol className="client-journey provider-invoice-steps">
            <li data-state={invoice ? "done" : "todo"}><span><ClipboardCheck className="size-4" aria-hidden /></span><small>{w.invoiceStepDraft}</small></li>
            <li data-state={invoice ? "done" : "todo"}><span><Send className="size-4" aria-hidden /></span><small>{w.invoiceStepSubmitted}</small></li>
            <li data-state={invoice ? "done" : "todo"}><span><Check className="size-4" aria-hidden /></span><small>{w.invoiceStepApproved}</small></li>
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
    <main className="client-page provider-workbench provider-company-security">
      <p className="provider-breadcrumb"><span>{w.companyTitle}</span><span aria-hidden>›</span><span>{w.tabSecurity}</span></p>
      <header className="provider-workbench-hero">
        <div>
          <h2>{w.companyTitle}</h2>
          <p>{w.companyLead}</p>
        </div>
        <p className="client-verified provider-secure-banner"><ShieldCheck className="size-4" aria-hidden />{w.companySecure} — {w.companySecureLead}</p>
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
      <section className="provider-company-layout">
        <div className="client-stack">
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
            <header className="client-priority-head"><h3>{w.companyOrgScope}</h3><span className="client-status-chip" data-tone="mint">{w.companyPrimaryOrg}</span></header>
            {members.length === 0 ? <p role="status">{w.sessionsEmpty}</p> : (
              <ul className="client-feed">
                {members.map((member) => (
                  <li key={member.id}><span><strong>{member.name}</strong><small>{member.role}</small></span></li>
                ))}
              </ul>
            )}
            <p className="client-access-note">{w.companyNoOtherOrg}</p>
          </article>
        </div>
        <div className="client-stack">
          <article className="client-card">
            <header><h3>{w.authSecurity}</h3></header>
            <p>{w.authSecurityLead}</p>
            <ul className="client-feed">
              <li><Lock className="size-4" aria-hidden /><span><strong>{w.mfaTitle}</strong><small>{w.mfaLead}</small></span><em className="client-status-chip" data-tone={mfaEnabled ? "mint" : "peach"}>{mfaLabel}</em></li>
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
        </div>
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
