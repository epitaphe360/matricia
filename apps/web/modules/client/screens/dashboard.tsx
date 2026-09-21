import Link from "next/link";
import {
  ArrowRight,
  Bell,
  Building2,
  CalendarDays,
  CheckCircle2,
  CircleDollarSign,
  ClipboardList,
  FileText,
  MessageSquare,
  Paperclip,
  Plus,
  Scale,
  Search,
  Sparkles,
  Zap,
} from "lucide-react";
import type { ComponentType, CSSProperties, ReactNode } from "react";
import { Alert, AlertDescription } from "@/modules/shared/ui/alert";
import { Button } from "@/modules/shared/ui/button";
import { dashboardHomeCopy } from "@/modules/shared/module-hub-copy";
import type { DashboardActionSummary } from "@/modules/shared/lib/action-center/dashboard-summary";
import type { UserActionItem } from "@/modules/shared/lib/action-center/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { clientDashboardCopy } from "@/modules/client/data/home/copy";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import type { ClientHomeSnapshot } from "@/modules/client/data/home/repository";
import {
  toClientDeadlineRows,
  toClientInboxRows,
  toClientPriorityRows,
  type ClientJourneyStepId,
  type ClientPrioritySituation,
} from "@/modules/client/data/home/view-model";
import { ClientWorkspaceNav } from "@/modules/client/ui/client-workspace-nav";

type FeaturedSteps = NonNullable<Extract<ClientHomeSnapshot, { status: "success" }>["featuredProject"]>["steps"];

function featuredStatusLabel(status: string, c: (typeof clientDashboardCopy)[Locale]) {
  if (status === "DRAFT") return c.statusDraft;
  if (status === "RFQ_OPEN") return c.statusMatching;
  if (status === "QUOTES_RECEIVED" || status === "CLIENT_REVIEW") return c.quotesReceived;
  if (status === "PROVIDER_SELECTED" || status === "CONTRACT_PENDING") return c.statusChoice;
  if (status === "MISSION_ACTIVE" || status === "IN_PROGRESS") return c.statusMission;
  return c.quotesReceived;
}

function homeStepLabel(id: "need" | "proposals" | "choice" | "mission", c: (typeof clientDashboardCopy)[Locale]) {
  if (id === "proposals") return c.homeStepProposals;
  if (id === "choice") return c.homeStepChoice;
  if (id === "mission") return c.homeStepMission;
  return c.homeStepNeed;
}

function compactHomeSteps(steps: FeaturedSteps) {
  const need = steps.find((step) => step.id === "need");
  const consultation = steps.find((step) => step.id === "consultation");
  const quotes = steps.find((step) => step.id === "quotes");
  const contract = steps.find((step) => step.id === "contract");
  const mission = steps.find((step) => step.id === "mission");
  const proposalsCurrent = Boolean(consultation?.current || quotes?.current);
  const proposalsDone = Boolean(quotes?.done || contract?.done || mission?.done);
  return [
    { id: "need" as const, done: Boolean(need?.done), current: Boolean(need?.current) },
    { id: "proposals" as const, done: proposalsDone && !proposalsCurrent, current: proposalsCurrent },
    { id: "choice" as const, done: Boolean(contract?.done), current: Boolean(contract?.current) },
    { id: "mission" as const, done: Boolean(mission?.done), current: Boolean(mission?.current) },
  ];
}

function journeyNext(id: ClientJourneyStepId | undefined, c: (typeof clientDashboardCopy)[Locale]) {
  if (id === "consultation") return c.nextConsultation;
  if (id === "quotes") return c.nextQuotes;
  if (id === "contract") return c.nextContract;
  if (id === "mission") return c.nextMission;
  if (id === "delivery") return c.nextDelivery;
  return c.nextNeed;
}

function actionIcon(situation: ClientPrioritySituation): ComponentType<{ className?: string }> {
  if (situation === "MESSAGE") return MessageSquare;
  if (situation === "DOCUMENT") return Paperclip;
  if (situation === "CONTRACT") return FileText;
  if (situation === "DELIVERABLE" || situation === "APPROVAL") return CheckCircle2;
  if (situation === "INVOICE") return CircleDollarSign;
  if (situation === "QUOTES") return Scale;
  return ClipboardList;
}

export function ClientDashboardHome({
  locale,
  userEmail,
  organizationName,
  selectedOrganizationId,
  selectedQuery,
  alternate,
  search,
  searchedItems,
  snapshot,
  membershipSwitcher,
  actionCenterError,
  showSignoutError,
  contextRejected,
  signOutAction,
  now,
}: {
  locale: Locale;
  userEmail: string | null;
  organizationName: string | null;
  selectedOrganizationId: string | null;
  selectedQuery: string;
  alternate: "fr" | "ar";
  search: string;
  searchedItems: readonly UserActionItem[];
  summary: DashboardActionSummary;
  snapshot: ClientHomeSnapshot;
  membershipSwitcher: ReactNode;
  actionCenterError: boolean;
  showSignoutError: boolean;
  contextRejected: boolean;
  signOutAction: (formData: FormData) => Promise<void>;
  now: string;
}): ReactNode {
  const m = dashboardHomeCopy[locale];
  const c = clientDashboardCopy[locale];
  const space = spaceCopy(locale);
  const priorityRows = toClientPriorityRows(searchedItems.slice(0, 3), locale, selectedQuery);
  const project = snapshot.status === "success" ? snapshot.featuredProject : null;
  const comparison = snapshot.status === "success" ? snapshot.comparison : null;
  const counts = snapshot.status === "success" ? snapshot.counts : null;
  const compareHref = comparison
    ? `/${locale}/client/demandes/${comparison.requestId}/offres${selectedQuery}`
    : null;
  const featuredOfferHref = comparison?.columns[0]
    ? `/${locale}/client/demandes/${comparison.requestId}/offres/${comparison.columns[0].quoteId}${selectedQuery}`
    : null;
  const insights = snapshot.insights;
  const currentStep = project?.steps.find((step) => step.current);
  const homeSteps = project ? compactHomeSteps(project.steps) : null;
  const pendingDecisions = counts?.pendingDecisions ?? 0;
  const documents = toClientInboxRows(searchedItems, "DOCUMENT", selectedQuery);
  const messages = toClientInboxRows(searchedItems, "MESSAGE", selectedQuery);
  const deadlines = toClientDeadlineRows({
    items: searchedItems,
    milestone: insights.nextMilestoneTitle ? { title: insights.nextMilestoneTitle, dueAt: insights.nextMilestoneDue } : null,
    missionsHref: `/${locale}/client/missions${selectedQuery}`,
    now,
    organizationQuery: selectedQuery,
  });
  const progressRows = counts
    ? [
        { label: c.kpiRequests, value: counts.openRequests ?? 0 },
        { label: c.kpiQuotes, value: counts.quotesToReview ?? 0 },
        { label: c.kpiMissions, value: counts.activeMissions ?? 0 },
      ]
    : [];
  const progressMax = progressRows.reduce((max, row) => Math.max(max, row.value), 1);

  const helloName = organizationName?.trim() || space.space;
  const messagesUnread = insights.messagesToHandle !== null && insights.messagesToHandle > 0;

  return (
    <div dir={locale === "ar" ? "rtl" : "ltr"} className="client-workspace">
      <aside className="client-side" aria-label={c.navHome}>
        <Link href={`/${locale}/tableau-de-bord${selectedQuery}`} className="client-brand">
          <span className="client-brand-mark" aria-hidden>M</span>
          <span>
            <strong>Matricia</strong>
            <small>{c.brandTagline}</small>
          </span>
        </Link>
        <ClientWorkspaceNav locale={locale} selectedQuery={selectedQuery} messagesUnread={messagesUnread} active="home" />
        <p className="client-side-foot"><span aria-hidden>◆</span>{c.brandFooter}</p>
      </aside>

      <div className="client-frame">
        <div className="client-scene" aria-hidden>
          <div className="client-scene-arch" />
          <div className="client-scene-palms" />
          <div className="client-scene-pattern" />
        </div>
        <div className="client-topbar">
          <div className="client-top-org">{membershipSwitcher}</div>
          <form className="client-top-search client-shell-search" method="get" action={`/${locale}/client/recherche`} role="search" aria-label={c.searchLabel}>
            {selectedOrganizationId ? <input type="hidden" name="organizationId" value={selectedOrganizationId} /> : null}
            <Search aria-hidden className="size-4" />
            <label className="sr-only" htmlFor="client-home-search">{c.searchLabel}</label>
            <input id="client-home-search" name="q" defaultValue={search} placeholder={c.searchSpace} />
          </form>
          <Link href={`/${alternate}/tableau-de-bord${selectedQuery}`} hrefLang={alternate} lang={alternate} className="client-lang-pair">{c.languagePair}</Link>
          <Link href={`/${locale}/notifications${selectedQuery}`} className="client-icon-btn" aria-label={c.notifications}><Bell className="size-4" /></Link>
          <span className="client-space-chip"><Building2 className="size-3.5" aria-hidden />{space.space}</span>
          <details className="client-account">
            <summary aria-label={c.accountMenu}>{userEmail?.slice(0, 1).toUpperCase() ?? "M"}</summary>
            <div>
              <p dir="ltr">{userEmail ?? "—"}</p>
              <Link href={`/${alternate}/tableau-de-bord${selectedQuery}`} hrefLang={alternate} lang={alternate}>{c.languagePair}</Link>
              <Link href={`/${locale}/notifications${selectedQuery}`}>{c.notifications}</Link>
              <Link href={`/${locale}/securite/sessions`}>{m.sessionsCta}</Link>
              <form action={signOutAction}>
                <input type="hidden" name="locale" value={locale} />
                <Button type="submit" className="client-ghost-btn">{m.signOut}</Button>
              </form>
            </div>
          </details>
        </div>

        <header className="client-mast client-home-mast">
          <div>
            <h1>{c.helloBonjour}, {helloName}.</h1>
            <p>{c.helloLead}</p>
          </div>
          <div className="client-home-mast-actions">
            <Link href={`/${locale}/besoin${selectedQuery}`} className="client-need-cta">
              <Plus aria-hidden className="size-4" />
              {c.primaryNeed}
            </Link>
            <small className="client-hello-kicker">{c.orgCaption}</small>
          </div>
        </header>

        <main className="client-page">
          {showSignoutError ? <Alert variant="destructive"><AlertDescription>{m.signOutError}</AlertDescription></Alert> : null}
          {contextRejected ? <Alert variant="destructive"><AlertDescription>{m.contextRejected}</AlertDescription></Alert> : null}

          <section className="client-home-hero">
            <article className="client-card client-featured" aria-labelledby="featured-project">
              <header>
                <h2 id="featured-project">{c.featuredProject}</h2>
                {project ? <span className="client-status-pill" data-tone="mint">{featuredStatusLabel(project.status, c)}</span> : null}
              </header>
              {project ? (
                <>
                  <div className="client-featured-head">
                    <strong>{project.title}</strong>
                    {project.quoteCount > 0 ? (
                      <p dir="ltr">{project.quoteCount} {c.stepQuotes.toLowerCase()} · {c.createdOn} {new Intl.DateTimeFormat(locale, { dateStyle: "medium" }).format(new Date(project.createdAt))}</p>
                    ) : null}
                  </div>
                  {homeSteps ? (
                    <ol className="client-home-pipeline">
                      {homeSteps.map((step) => (
                        <li key={step.id} data-state={step.current ? "current" : step.done ? "done" : "todo"}>
                          <span aria-hidden />
                          <span>{homeStepLabel(step.id, c)}</span>
                        </li>
                      ))}
                    </ol>
                  ) : null}
                  <div className="client-featured-note">
                    <p><Sparkles aria-hidden className="size-4" />{journeyNext(currentStep?.id, c)}</p>
                  </div>
                  <Link href={project.href} className="client-text-link">{c.seeProject}<ArrowRight aria-hidden className="size-4 rtl:rotate-180" /></Link>
                </>
              ) : (
                <p>{c.noProject} <Link href={`/${locale}/besoin${selectedQuery}`}>{c.primaryNeed}</Link></p>
              )}
            </article>

            <article className="client-card" aria-labelledby="treat-now">
              <header>
                <h2 id="treat-now"><Zap aria-hidden className="size-4" />{c.treatNow}</h2>
                <Link href={`/${locale}/client/actions${selectedQuery}`} className="client-text-link">{c.actionsTitle}<ArrowRight aria-hidden className="size-4 rtl:rotate-180" /></Link>
              </header>
              {actionCenterError ? <p role="alert">{m.feedError}</p> : priorityRows.length === 0 ? (
                <p>{c.noActions} <Link href={`/${locale}/client/diagnostics${selectedQuery}`}>{c.primaryDiagnostic}</Link></p>
              ) : (
                <section className="client-treat">
                  {priorityRows.map((row) => {
                    const Icon = actionIcon(row.situation);
                    return (
                      <Link key={row.id} href={row.href} className="client-treat-tile">
                        <span className="client-action-icon" data-tone={row.tone} aria-hidden><Icon className="size-4" /></span>
                        <div>
                          <strong>{row.title}</strong>
                          <small>{row.dossier}</small>
                        </div>
                        <ArrowRight aria-hidden className="size-4 rtl:rotate-180" />
                      </Link>
                    );
                  })}
                </section>
              )}
            </article>

            <article className="client-card client-decisions" aria-labelledby="decisions-ring">
              <header>
                <h2 id="decisions-ring">{c.kpiDecisions}</h2>
              </header>
              {counts === null ? <p>{c.unavailable}</p> : (
                <div className="client-decisions-ring-wrap">
                  <div
                    className="client-decisions-ring"
                    style={{ "--decisions-fill": `${Math.min(100, pendingDecisions * 20 + 12)}%` } as CSSProperties}
                    role="img"
                    aria-label={`${pendingDecisions} ${c.decisionsPending}`}
                  >
                    <span dir="ltr">{pendingDecisions}</span>
                  </div>
                  <p>{pendingDecisions} {c.decisionsPending}</p>
                  <small>{c.decisionsCaption}</small>
                  {pendingDecisions > 0 ? (
                    <Link href={`/${locale}/client/demandes${selectedQuery}`} className="client-text-link">{c.openItem}<ArrowRight aria-hidden className="size-4 rtl:rotate-180" /></Link>
                  ) : null}
                </div>
              )}
            </article>
          </section>

          <section className="client-board client-board-compare client-home-analytics">
            <article className="client-card" aria-labelledby="progress-title">
              <header>
                <h2 id="progress-title">{c.projectProgress}</h2>
                <small>{c.progressLead}</small>
              </header>
              {counts === null ? <p>{c.unavailable}</p> : progressRows.every((row) => row.value === 0) ? (
                <p>{c.progressEmpty}</p>
              ) : (
                <div className="client-home-spark">
                  <svg viewBox="0 0 320 120" role="img" aria-label={c.projectProgress}>
                    {progressRows.map((row, index) => {
                      const y = 100 - Math.round((row.value / progressMax) * 72);
                      const color = index === 0 ? "#7c6bf0" : index === 1 ? "#e07a5f" : "#2f9d64";
                      return <polyline key={row.label} fill="none" stroke={color} strokeWidth="3" points={`16,100 112,${y + 8} 208,${y} 304,${Math.max(28, y - 10)}`} />;
                    })}
                  </svg>
                  <ul className="client-home-progress">
                    <li><span data-tone="violet" /><span>{c.progressPrep}</span><strong dir="ltr">{counts.openRequests}</strong></li>
                    <li><span data-tone="peach" /><span>{c.progressRun}</span><strong dir="ltr">{counts.activeMissions}</strong></li>
                    <li><span data-tone="mint" /><span>{c.progressReview}</span><strong dir="ltr">{counts.quotesToReview}</strong></li>
                  </ul>
                </div>
              )}
            </article>

            <article className="client-card client-compare" aria-labelledby="compare-title">
              <header>
                <h2 id="compare-title"><Scale aria-hidden className="size-4" />{c.compareWhatMatters}</h2>
                {compareHref ? <Link href={compareHref} className="client-text-link">{c.compareTitle}<ArrowRight aria-hidden className="size-4 rtl:rotate-180" /></Link> : null}
              </header>
              {comparison && comparison.columns.length > 0 ? (
                <div className="client-home-criteria">
                  {comparison.columns.slice(0, 2).map((column, index) => {
                    const maxDeliverables = Math.max(...comparison.columns.map((item) => item.deliverablesCount), 1);
                    const durations = comparison.columns.map((item) => item.durationDays).filter((value) => value > 0);
                    const minDays = durations.length > 0 ? Math.min(...durations) : 0;
                    const scopePct = Math.round((column.deliverablesCount / maxDeliverables) * 100);
                    const delayPct = column.durationDays > 0 && minDays > 0 ? Math.round((minDays / column.durationDays) * 100) : 0;
                    return (
                      <div key={column.quoteId} className="client-home-criteria-offer">
                        <strong>{column.label || (index === 0 ? c.offerA : c.offerB)}</strong>
                        <div className="client-home-bar-row">
                          <span>{c.scope}</span>
                          <div className="client-home-bar-track" aria-hidden><span data-offer={index === 0 ? "a" : "b"} style={{ width: `${scopePct}%` }} /></div>
                          <em dir="ltr">{column.deliverablesCount}</em>
                        </div>
                        <div className="client-home-bar-row">
                          <span>{c.timeline}</span>
                          <div className="client-home-bar-track" aria-hidden><span data-offer={index === 0 ? "a" : "b"} style={{ width: `${delayPct}%` }} /></div>
                          <em dir="ltr">{column.durationDays} {c.days}</em>
                        </div>
                      </div>
                    );
                  })}
                  <p className="client-home-bar-caption">{comparison.description}</p>
                  {featuredOfferHref ? <Link href={featuredOfferHref} className="client-text-link">{c.seeDetail}<ArrowRight aria-hidden className="size-4 rtl:rotate-180" /></Link> : null}
                </div>
              ) : <p>{c.noComparison}</p>}
            </article>
          </section>

          <section className="client-insights client-home-insights">
            <Link href={`/${locale}/client/documents${selectedQuery}`} className="client-card client-insight-kpi" data-tone="violet">
              <span className="client-feed-icon" data-tone="violet" aria-hidden><FileText className="size-4" /></span>
              <h2>{c.documentsInsight}</h2>
              {insights.documentsToReview === null ? <p>{c.unavailable}</p> : (
                <>
                  <strong dir="ltr">{insights.documentsToReview}</strong>
                  <p>{documents[0]?.title ?? c.documentsCaption}</p>
                </>
              )}
            </Link>
            <Link href={deadlines[0]?.href ?? `/${locale}/client/missions${selectedQuery}`} className="client-card client-insight-kpi" data-tone="peach">
              <span className="client-feed-icon" data-tone="peach" aria-hidden><CalendarDays className="size-4" /></span>
              <h2>{c.nextMilestone}</h2>
              {deadlines.length === 0 ? <p>{c.noMilestone}</p> : (
                <>
                  <strong>{deadlines[0]?.title}</strong>
                  <p>{c.milestonePlan}</p>
                </>
              )}
            </Link>
            <Link href={`/${locale}/messagerie${selectedQuery}`} className="client-card client-insight-kpi" data-tone="mint">
              <span className="client-feed-icon" data-tone="mint" aria-hidden><MessageSquare className="size-4" /></span>
              <h2>{c.unreadMessages}</h2>
              {insights.messagesToHandle === null ? <p>{c.unavailable}</p> : (
                <>
                  <strong dir="ltr">{insights.messagesToHandle}</strong>
                  <p>{messages[0]?.title ?? c.messagesContinue}</p>
                </>
              )}
            </Link>
            <aside className="client-card client-home-art" aria-hidden>
              <p>{c.orgCaption}</p>
            </aside>
          </section>

          <p className="client-home-footer-strip">{c.homeFooterStrip}</p>

          {snapshot.status === "error" ? <p className="admin-notice">{c.snapshotError}</p> : null}
        </main>
      </div>
    </div>
  );
}
