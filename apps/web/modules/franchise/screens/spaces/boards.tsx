import Link from "next/link";
import { ArrowRight, Bell, Briefcase, FileText, LineChart, MapPin, ShieldCheck, Users } from "lucide-react";
import type { ReactNode } from "react";
import { PIPELINE_STAGES } from "@/modules/franchise/data/crm/model";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { franchiseCopy } from "@/modules/franchise/data/spaces/copy";
import { franchiseStageLabel } from "@/modules/franchise/data/spaces/labels";
import { canApplyFranchiseSpaceDemo, demoFranchiseSpaces, type FranchiseSpaceBoardData } from "@/modules/franchise/data/spaces/demo";
import { emptyFranchiseSpaces } from "@/modules/franchise/data/spaces/live";
import { MandateBanner } from "@/modules/franchise/screens/library/library-boards";
import { FranchiseMandateRail } from "@/modules/franchise/screens/library/library-chrome";
import { canMutateFranchiseFolder, FranchiseFolderActivityForm, FranchiseFolderAdvanceForm, FranchiseFolderTimeline } from "@/modules/franchise/screens/network/folder-forms";
import {
  FranchiseAnomalyDefinitionForm,
  FranchiseIncidentInstructForm,
  FranchiseMandateInviteForm,
  FranchiseQualificationDecisionForm,
  FranchiseRecommendationDefinitionForm,
  FranchiseRiskDefinitionForm,
  FranchiseVolumeProposeForm,
} from "@/modules/franchise/screens/spaces/command-forms";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

type SpaceBoardProps = {
  locale: Locale;
  query: string;
  mandateName?: string | null;
  view?: string | null;
  itemId?: string | null;
  search?: string;
  stageFilter?: string;
  ownerFilter?: string;
  page?: string;
  board?: FranchiseSpaceBoardData;
  libraryId?: string | null;
  organizationId?: string | null;
  services?: Array<{ id: string; title: string }>;
};

const PAGE_SIZE = 8;

function pageNumber(page?: string) {
  const value = Number.parseInt(page ?? "1", 10);
  return Number.isInteger(value) && value > 0 ? value : 1;
}

function withPage(query: string, page: number) {
  const params = new URLSearchParams(query.startsWith("?") ? query.slice(1) : query);
  if (page <= 1) params.delete("page");
  else params.set("page", String(page));
  const next = params.toString();
  return next ? `?${next}` : "";
}

function paginate<T>(rows: T[], page?: string) {
  const current = pageNumber(page);
  const pageCount = Math.max(1, Math.ceil(rows.length / PAGE_SIZE) || 1);
  const safe = Math.min(current, pageCount);
  return { rows: rows.slice((safe - 1) * PAGE_SIZE, safe * PAGE_SIZE), page: safe, pageCount };
}

function PaginationNav({ path, query, page, pageCount, label }: { path: string; query: string; page: number; pageCount: number; label: string }) {
  return (
    <nav className="franchise-pagination" aria-label={label}>
      {Array.from({ length: pageCount }, (_, index) => index + 1).map((n) => (
        n === page ? <span key={n} aria-current="page">{n}</span> : <Link key={n} href={`${path}${withPage(query, n)}`}>{n}</Link>
      ))}
    </nav>
  );
}

function organizationIdFromQuery(query: string) {
  return new URLSearchParams(query.startsWith("?") ? query.slice(1) : query).get("organizationId") ?? "";
}

function folderEvidence(row: { activities?: Array<{ evidence: string[] }>; pipelineEvents?: Array<{ evidence: string[] }> }) {
  return [...(row.activities ?? []), ...(row.pipelineEvents ?? [])].flatMap((item) => item.evidence);
}

function matchesNetworkFilter(view: string | null | undefined, stage?: string) {
  if (!view || view === "all" || view === "inviter") return true;
  if (view === "accompagnement") return stage === "SENT" || stage === "OPENED";
  if (view === "incomplets") return stage === "REGISTERED" || stage === "PROFILE_STARTED" || stage === "DIAGNOSTIC_STARTED";
  if (view === "qualifies") return stage === "VERIFIED" || stage === "OPPORTUNITY_CREATED" || stage === "RFQ_STARTED" || stage === "CONTRACT_SIGNED";
  if (view === "inactifs") return stage === "INACTIVE";
  return true;
}

function resolveBoard(props: SpaceBoardProps) {
  if (props.board) return props.board;
  return canApplyFranchiseSpaceDemo() ? demoFranchiseSpaces(props.locale, props.query) : emptyFranchiseSpaces(props.locale, props.query);
}

function Cta({ href, children, soft = false }: { href: string; children: ReactNode; soft?: boolean }) {
  return <Link href={href} className={soft ? "client-soft-link" : "franchise-tool"}>{children}<ArrowRight className="size-4 rtl:rotate-180" aria-hidden /></Link>;
}

function Banner({ locale, mandateName }: SpaceBoardProps) {
  const n = libraryCopy(locale);
  return <MandateBanner locale={locale} name={mandateName ?? n.mandate} />;
}

export function FranchiseHomeBoard({ locale, query, mandateName, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-treat">
        {demo.treat.map((item) => (
          <Link key={item.id} href={item.href} className="franchise-kpi-tile" data-tone={item.tone}>
            <span className="franchise-kpi-icon" data-tone={item.tone}><FileText className="size-4" aria-hidden /></span>
            <span><strong>{item.title}</strong><small>{item.detail}</small></span>
            <ArrowRight className="size-4 rtl:rotate-180" aria-hidden />
          </Link>
        ))}
      </section>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{c.viewPerimeter}</h2></header>
          <ol className="franchise-pipeline">
            {demo.pipeline.map((step, index) => {
              const Icon = [Users, FileText, Briefcase, ShieldCheck, LineChart][index] ?? Users;
              return (
                <li key={step.id}>
                  <span className="franchise-pipe-row">
                    <span className="franchise-pipe-icon" data-tone={step.tone}><Icon className="size-4" aria-hidden /></span>
                    {index < demo.pipeline.length - 1 ? <span className="franchise-pipe-arrow" aria-hidden /> : null}
                  </span>
                  <strong>{step.title}</strong>
                  <small>{step.detail}</small>
                  <em className="client-status-chip" data-tone={step.tone}>{step.status}</em>
                </li>
              );
            })}
          </ol>
          <p className="client-access-note">{c.scopeNote}</p>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.treatNow}</h2></header>
          <ul className="franchise-dot-list">
            {demo.attention.map((item) => (
              <li key={item.id}>
                <span className="franchise-dot" data-tone="peach" />
                <strong>{item.title}</strong>
                <Cta href={item.href} soft>{c.open}</Cta>
              </li>
            ))}
          </ul>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function PerimeterBoard({ locale, query, mandateName, view, board, organizationId }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{view === "utilisateurs" ? c.users : c.authorized}</h2></header>
          <nav className="franchise-inspector-tabs" aria-label={c.authorized}>
            <Link href={`/${locale}/franchise/perimetre${query}`} data-active={!view ? "true" : undefined}>{c.authorized}</Link>
            <Link href={`/${locale}/franchise/perimetre/utilisateurs${query}`} data-active={view === "utilisateurs" ? "true" : undefined}>{c.users}</Link>
          </nav>
          {view === "utilisateurs" ? (
            <>
              {demo.users.length === 0 ? <p>{c.emptyUsers}</p> : (
                <ul className="client-feed">
                  {demo.users.map((row) => (
                    <li key={row.id}><span><strong>{row.title}</strong><small>{row.meta}</small></span><em className="client-status-chip">{row.status}</em></li>
                  ))}
                </ul>
              )}
              {demo.canWrite && (organizationId || organizationIdFromQuery(query)) ? (
                <FranchiseMandateInviteForm locale={locale} organizationId={organizationId || organizationIdFromQuery(query)} />
              ) : null}
            </>
          ) : (
            <ul className="client-feed">
              <li><MapPin className="size-4" aria-hidden /><span><strong>{c.territory}</strong><small>{demo.perimeter.territory}</small></span></li>
              <li><FileText className="size-4" aria-hidden /><span><strong>{c.domains}</strong><small>{demo.perimeter.domains}</small></span></li>
              <li><ShieldCheck className="size-4" aria-hidden /><span><strong>{c.mandate}</strong><small>{demo.perimeter.mandate}</small></span></li>
              <li><span><strong>{c.state}</strong></span><em className="client-status-chip" data-tone="mint">{demo.perimeter.status}</em></li>
            </ul>
          )}
          <div className="franchise-map" aria-hidden><span className="franchise-compass">✧</span></div>
        </article>
        <div className="client-stack">
          <article className="client-card">
            <header><h2>{c.canDo}</h2></header>
            <ul className="franchise-can">{demo.canDo.map((item) => <li key={item}>{item}</li>)}</ul>
          </article>
          <article className="client-card">
            <header><h2>{c.needsVal}</h2></header>
            <ul className="franchise-cannot">{demo.needsValidation.map((item) => <li key={item}>{item}</li>)}</ul>
          </article>
          <p className="client-access-note">{c.periNote}</p>
        </div>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function NetworkBoard({ locale, query, mandateName, view, itemId, search, page, board, organizationId }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const selected = itemId ? demo.people.find((row) => row.id === itemId) ?? null : null;
  const needle = (search ?? "").trim().toLocaleLowerCase();
  const filtered = demo.people.filter((row) => matchesNetworkFilter(view, row.stage) && (!needle || `${row.name} ${row.services} ${row.status}`.toLocaleLowerCase().includes(needle)));
  const paged = paginate(filtered, page);
  const people = paged.rows;
  const tab = (href: string, label: string, active: boolean) => <Link href={href} data-active={active ? "true" : undefined}>{label}</Link>;
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <div className="franchise-toolbar">
        <form action={`/${locale}/franchise/fournisseurs${query}`} method="get" className="franchise-search">
          {organizationIdFromQuery(query) ? <input type="hidden" name="organizationId" value={organizationIdFromQuery(query)} /> : null}
          <label><span className="sr-only">{c.searchPro}</span><input name="q" defaultValue={search} placeholder={c.searchPro} /></label>
          <button type="submit" className="franchise-scope-chip">{c.searchPro}</button>
        </form>
        <Link href={`/${locale}/franchise/fournisseurs/inviter${query}`} className="franchise-tool franchise-tool-primary">{c.invite}</Link>
        <Link href={`/${locale}/franchise/clients/inviter${query}`} className="franchise-tool">{c.inviteClient}</Link>
      </div>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{c.netPeople}</h2></header>
          <nav className="franchise-inspector-tabs" aria-label={c.netPeople}>
            {tab(`/${locale}/franchise/fournisseurs${query}`, c.all, !view || view === "all")}
            {tab(`/${locale}/franchise/fournisseurs/accompagnement${query}`, c.toSupport, view === "accompagnement")}
            {tab(`/${locale}/franchise/fournisseurs/incomplets${query}`, c.incomplete, view === "incomplets")}
            {tab(`/${locale}/franchise/fournisseurs/qualifies${query}`, c.qualified, view === "qualifies")}
            {tab(`/${locale}/franchise/fournisseurs/inactifs${query}`, c.inactive, view === "inactifs")}
          </nav>
          <div className="client-table-wrap" id="reseau">
            <table className="client-space-table">
              <thead><tr><th>{c.profile}</th><th>{c.services}</th><th>{c.folderState}</th><th>{c.nextAction}</th><th>{c.action}</th></tr></thead>
              <tbody>
                {people.length === 0 ? (
                  <tr><td colSpan={5}>{c.emptyPeople}</td></tr>
                ) : people.map((row) => (
                  <tr key={row.id}>
                    <td><span className="franchise-row-title"><span className="franchise-kpi-icon" data-tone={row.tone}>{row.name.slice(0, 1)}</span>{row.name}</span></td>
                    <td>{row.services}</td>
                    <td><span className="client-status-chip" data-tone={row.tone}>{row.status}</span></td>
                    <td>{row.next}</td>
                    <td><Cta href={`/${locale}/franchise/fournisseurs/${row.id}${query}`} soft>{c.openFolder}</Cta></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <PaginationNav path={`/${locale}/franchise/fournisseurs`} query={query} page={paged.page} pageCount={paged.pageCount} label={c.netPeople} />
        </article>
        <article className="client-card">
          <header><h2>{selected ? selected.name : c.prioritize}</h2></header>
          {selected ? (
            <>
              <p>{selected.email ?? selected.services}</p>
              <em className="client-status-chip" data-tone={selected.tone}>{selected.status}</em>
              <nav className="franchise-inspector-tabs" aria-label={selected.name}>
                <Link href={`/${locale}/franchise/fournisseurs/${selected.id}${query}`} data-active={!view || view === "qualification" ? "true" : undefined}>{c.stepQual}</Link>
                <Link href={`/${locale}/franchise/fournisseurs/${selected.id}/capacite${query}`} data-active={view === "capacite" ? "true" : undefined}>{c.capacityTitle}</Link>
                <Link href={`/${locale}/franchise/fournisseurs/${selected.id}/documents${query}`} data-active={view === "documents" ? "true" : undefined}>{c.document}</Link>
              </nav>
              {view === "capacite" ? (
                <>
                  <p>{c.capacityLead}</p>
                  <p>{selected.nextFollowupAt ? selected.nextFollowupAt.slice(0, 10) : c.noCapacity}</p>
                  {canMutateFranchiseFolder(selected.id, demo.canWrite) ? <FranchiseFolderActivityForm locale={locale} organizationId={organizationIdFromQuery(query) || null} prospectId={selected.id} defaultType="FOLLOW_UP" /> : null}
                </>
              ) : view === "documents" ? (
                <>
                  {folderEvidence(selected).length ? (
                    <ul className="client-feed">
                      {folderEvidence(selected).map((ref) => (
                        <li key={ref}><span><strong>{ref}</strong><small>{c.evidence}</small></span></li>
                      ))}
                    </ul>
                  ) : <p className="franchise-empty-panel">{c.noEvidence}</p>}
                  {canMutateFranchiseFolder(selected.id, demo.canWrite) ? <FranchiseFolderActivityForm locale={locale} organizationId={organizationIdFromQuery(query) || null} prospectId={selected.id} defaultType="NOTE" /> : null}
                </>
              ) : (
                <>
                  <ol className="franchise-mini-pipe">
                    {PIPELINE_STAGES.map((stage, index) => (
                      <li key={stage} data-active={selected.stage === stage ? "true" : undefined}><em>{index + 1}</em><strong>{franchiseStageLabel(stage, locale)}</strong></li>
                    ))}
                  </ol>
                  <FranchiseFolderTimeline locale={locale} activities={selected.activities} events={selected.pipelineEvents} />
                  {canMutateFranchiseFolder(selected.id, demo.canWrite) && selected.rowVersion ? (
                    <FranchiseFolderAdvanceForm locale={locale} organizationId={organizationIdFromQuery(query) || null} prospectId={selected.id} stage={selected.stage ?? "SENT"} rowVersion={selected.rowVersion} />
                  ) : null}
                  {canMutateFranchiseFolder(selected.id, demo.canWrite) ? <FranchiseFolderActivityForm locale={locale} organizationId={organizationIdFromQuery(query) || null} prospectId={selected.id} defaultType="NOTE" /> : null}
                  {demo.qualifications.length === 0 ? <p className="franchise-empty-panel">{c.emptyQualifications}</p> : (
                    <ul className="client-feed">
                      {demo.qualifications.map((row) => (
                        <li key={row.id}><span><strong>{row.title}</strong><small>{row.meta ?? row.status}</small></span><em className="client-status-chip">{row.status}</em></li>
                      ))}
                    </ul>
                  )}
                  {demo.canWrite ? (
                    <FranchiseQualificationDecisionForm
                      locale={locale}
                      organizationId={organizationId || organizationIdFromQuery(query) || null}
                      qualifications={demo.qualifications.filter((row) => row.rowVersion)}
                    />
                  ) : null}
                </>
              )}
            </>
          ) : (
          <ul className="franchise-dot-list">
            {people.slice(0, 5).map((row) => (
              <li key={`prio-${row.id}`}>
                <span className="franchise-dot" data-tone={row.tone} />
                <span><strong>{row.name}</strong><small>{row.status}</small></span>
                <Cta href={`/${locale}/franchise/relances${query}`} soft>{c.contact}</Cta>
              </li>
            ))}
          </ul>
          )}
          <h3>{c.integration}</h3>
          <ol className="franchise-mini-pipe">
            <li data-active="true"><em>1</em><strong>{c.stepInvite}</strong></li>
            <li><em>2</em><strong>{c.stepFolder}</strong></li>
            <li><em>3</em><strong>{c.stepQual}</strong></li>
            <li><em>4</em><strong>{c.stepActivity}</strong></li>
            <li><em>5</em><strong>{c.stepFollow}</strong></li>
          </ol>
          <p className="client-access-note">{c.privacyLead}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function FranchiseRequestsBoard({ locale, query, mandateName, view, itemId, search, stageFilter, ownerFilter, page, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const href = `/${locale}/franchise/demandes${query}`;
  const selected = itemId ? demo.requests.find((row) => row.id === itemId) ?? null : null;
  const needle = (search ?? "").trim().toLocaleLowerCase();
  const owners = [...new Set(demo.requests.map((row) => row.owner))];
  const filtered = demo.requests.filter((row) => {
    if (stageFilter && stageFilter !== "all" && row.stageCode !== stageFilter) return false;
    if (ownerFilter && ownerFilter !== "all" && row.owner !== ownerFilter) return false;
    return !needle || `${row.title} ${row.owner} ${row.stage} ${row.flag}`.toLocaleLowerCase().includes(needle);
  });
  const supervision = view === "devis" ? demo.quotes : view === "missions" ? demo.missions : null;
  const paged = paginate(filtered, page);
  const requests = paged.rows;
  const org = organizationIdFromQuery(query);
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <form action={`/${locale}/franchise/demandes`} method="get" className="franchise-filters">
        {org ? <input type="hidden" name="organizationId" value={org} /> : null}
        <label><span className="sr-only">{c.search}</span><input name="q" defaultValue={search} placeholder={c.search} /></label>
        <label>
          <span className="sr-only">{c.allStages}</span>
          <select name="stage" defaultValue={stageFilter || "all"}>
            <option value="all">{c.allStages}</option>
            {PIPELINE_STAGES.map((stage) => <option key={stage} value={stage}>{franchiseStageLabel(stage, locale)}</option>)}
          </select>
        </label>
        <label>
          <span className="sr-only">{c.allOwners}</span>
          <select name="owner" defaultValue={ownerFilter || "all"}>
            <option value="all">{c.allOwners}</option>
            {owners.map((owner) => <option key={owner} value={owner}>{owner}</option>)}
          </select>
        </label>
        <button type="submit" className="franchise-scope-chip">{c.filter}</button>
        <Link href={href} className="franchise-tool">{c.reset}</Link>
        <Link href={`/${locale}/franchise/clients/inviter${query}`} className="franchise-tool franchise-tool-primary">{c.inviteClient}</Link>
      </form>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{view === "devis" ? c.quotes : view === "missions" ? c.missions : c.folders}</h2></header>
          <nav className="franchise-inspector-tabs" aria-label={c.folders}>
            <Link href={`/${locale}/franchise/demandes${query}`} data-active={!view || (view !== "devis" && view !== "missions") ? "true" : undefined}>{c.folders}</Link>
            <Link href={`/${locale}/franchise/demandes/devis${query}`} data-active={view === "devis" ? "true" : undefined}>{c.quotes}</Link>
            <Link href={`/${locale}/franchise/demandes/missions${query}`} data-active={view === "missions" ? "true" : undefined}>{c.missions}</Link>
          </nav>
          <div className="client-table-wrap">
            <table className="client-space-table">
              <thead><tr><th>{c.folder}</th><th>{c.stage}</th><th>{c.owner}</th><th>{c.flag}</th><th>{c.action}</th></tr></thead>
              <tbody>
                {supervision ? (
                  supervision.length === 0 ? (
                    <tr><td colSpan={5}>{view === "devis" ? c.emptyQuotes : c.emptyMissions}</td></tr>
                  ) : supervision.map((row) => (
                    <tr key={row.id}>
                      <td>{row.title}</td>
                      <td><span className="client-status-chip">{row.status}</span></td>
                      <td>{row.meta ?? "—"}</td>
                      <td>—</td>
                      <td><Cta href={row.href} soft>{c.open}</Cta></td>
                    </tr>
                  ))
                ) : requests.length === 0 ? (
                  <tr><td colSpan={5}>{c.emptyRequests}</td></tr>
                ) : requests.map((row) => (
                  <tr key={row.id}>
                    <td><span className="franchise-row-title"><span className="franchise-kpi-icon" data-tone={row.tone}><FileText className="size-4" aria-hidden /></span>{row.title}</span></td>
                    <td><span className="client-status-chip" data-tone={row.tone}>{row.stage}</span></td>
                    <td>{row.owner}</td>
                    <td>{row.flag}</td>
                    <td><Cta href={`/${locale}/franchise/demandes/${row.id}${query}`} soft>{c.open}</Cta></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {supervision ? null : <PaginationNav path={`/${locale}/franchise/demandes`} query={query} page={paged.page} pageCount={paged.pageCount} label={c.folders} />}
        </article>
        <article className="client-card">
          <header><h2>{selected ? selected.title : c.orient}</h2></header>
          <nav className="franchise-inspector-tabs" aria-label={c.orient}>
            <Link href={itemId ? `/${locale}/franchise/demandes/${itemId}${query}` : href} data-active={!view ? "true" : undefined}>{c.openFolder}</Link>
            <Link href={itemId ? `/${locale}/franchise/demandes/${itemId}/matching${query}` : href} data-active={view === "matching" ? "true" : undefined}>{c.matching}</Link>
            <Link href={itemId ? `/${locale}/franchise/demandes/${itemId}/consultation${query}` : href} data-active={view === "consultation" ? "true" : undefined}>{c.consult}</Link>
            <Link href={itemId ? `/${locale}/franchise/demandes/${itemId}/suivi${query}` : href} data-active={view === "suivi" ? "true" : undefined}>{c.follow}</Link>
          </nav>
          {selected && view === "matching" ? (
            <>
              <p>{c.matchingLead}</p>
              {selected.matching?.length ? (
                <ul className="client-feed">
                  {selected.matching.map((row) => (
                    <li key={row.id}><span><strong>{row.name}</strong><small>{row.status}</small></span><Cta href={row.href} soft>{c.openFolder}</Cta></li>
                  ))}
                </ul>
              ) : <p className="franchise-empty-panel">{c.emptyMatching}</p>}
            </>
          ) : selected && view === "consultation" ? (
            <>
              <FranchiseFolderTimeline locale={locale} activities={selected.activities} />
              {canMutateFranchiseFolder(selected.id, demo.canWrite) ? <FranchiseFolderActivityForm locale={locale} organizationId={org || null} prospectId={selected.id} defaultType="NOTE" /> : null}
            </>
          ) : selected && view === "suivi" ? (
            <>
              <FranchiseFolderTimeline locale={locale} events={selected.pipelineEvents} activities={selected.activities} />
              <p>{selected.nextFollowupAt ? selected.nextFollowupAt.slice(0, 10) : c.suiviEmpty}</p>
              {canMutateFranchiseFolder(selected.id, demo.canWrite) && selected.rowVersion && selected.stageCode ? (
                <FranchiseFolderAdvanceForm locale={locale} organizationId={org || null} prospectId={selected.id} stage={selected.stageCode} rowVersion={selected.rowVersion} />
              ) : null}
            </>
          ) : (
            <>
              <header className="franchise-section-head"><h2>{c.reqJourney}</h2></header>
              <ol className="franchise-mini-pipe">
                <li data-active="true"><em>1</em><strong>{c.need}</strong><small>{c.needLead}</small></li>
                <li><em>2</em><strong>{c.structure}</strong><small>{c.structureLead}</small></li>
                <li><em>3</em><strong>{c.consult}</strong><small>{c.consultLead}</small></li>
                <li><em>4</em><strong>{c.offer}</strong><small>{c.offerLead}</small></li>
                <li><em>5</em><strong>{c.mission}</strong><small>{c.missionLead}</small></li>
                <li><em>6</em><strong>{c.follow}</strong><small>{c.followLead}</small></li>
              </ol>
            </>
          )}
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function QualityBoard({ locale, query, mandateName, view, search, page, board, libraryId, organizationId, services }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const needle = (search ?? "").trim().toLocaleLowerCase();
  const matches = (value: string) => !needle || value.toLocaleLowerCase().includes(needle);
  const qualityPath = view ? `/${locale}/franchise/qualite/${view}` : `/${locale}/franchise/qualite`;
  const supervision = view === "anomalies" ? demo.anomalies
    : view === "recommandations" ? demo.recommendations
      : view === "opportunites" ? demo.opportunities
        : view === "definitions" ? demo.definitions
          : view === "risques" ? demo.risks
            : view === "incidents" ? demo.incidents
              : null;
  const pagedSupervision = paginate(supervision?.filter((row) => matches(`${row.title} ${row.status} ${row.meta ?? ""}`)) ?? [], page);
  const pagedQuality = paginate(demo.quality.filter((row) => matches(`${row.title} ${row.type} ${row.status}`)), page);
  const supervisionEmpty = view === "anomalies" ? c.emptyAnomalies
    : view === "recommandations" ? c.emptyRecommendations
      : view === "opportunites" ? c.emptyOpportunities
        : view === "definitions" ? c.emptyDefinitions
          : view === "risques" ? c.emptyRisks
            : c.emptyIncidents;
  const steps = [
    { t: c.stepConsult, d: c.stepConsultLead },
    { t: c.stepExam, d: c.stepExamLead },
    { t: c.stepMotive, d: c.stepMotiveLead },
    { t: c.stepControl, d: c.stepControlLead },
  ];
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-treat">
        {demo.obligations.map((item, index) => (
          <article key={item.id} className="franchise-kpi-tile" data-tone={(["sky", "violet", "mint", "peach"] as const)[index] ?? "sky"}>
            <span className="franchise-kpi-icon"><FileText className="size-4" aria-hidden /></span>
            <span><strong>{item.title}</strong><small>{item.detail}</small></span>
          </article>
        ))}
      </section>
      <form action={qualityPath} method="get" className="franchise-filters">
        {organizationIdFromQuery(query) ? <input type="hidden" name="organizationId" value={organizationIdFromQuery(query)} /> : null}
        <label><span className="sr-only">{c.search}</span><input name="q" defaultValue={search} placeholder={c.search} /></label>
        <button type="submit" className="franchise-scope-chip">{c.filter}</button>
      </form>
      <section className="franchise-workbench">
        <article className="client-card">
          <nav className="franchise-inspector-tabs" aria-label={c.toExamine}>
            <Link href={`/${locale}/franchise/qualite${query}`} data-active={!view ? "true" : undefined}>{c.toExamine}</Link>
            <Link href={`/${locale}/franchise/qualite/revues${query}`} data-active={view === "revues" ? "true" : undefined}>{c.stepExam}</Link>
            <Link href={`/${locale}/franchise/qualite/non-conformites${query}`} data-active={view === "non-conformites" ? "true" : undefined}>{c.stepMotive}</Link>
            <Link href={`/${locale}/franchise/qualite/actions${query}`} data-active={view === "actions" ? "true" : undefined}>{c.stepControl}</Link>
            <Link href={`/${locale}/franchise/qualite/anomalies${query}`} data-active={view === "anomalies" ? "true" : undefined}>{c.anomalies}</Link>
            <Link href={`/${locale}/franchise/qualite/recommandations${query}`} data-active={view === "recommandations" ? "true" : undefined}>{c.recommendations}</Link>
            <Link href={`/${locale}/franchise/qualite/opportunites${query}`} data-active={view === "opportunites" ? "true" : undefined}>{c.opportunities}</Link>
            <Link href={`/${locale}/franchise/qualite/definitions${query}`} data-active={view === "definitions" ? "true" : undefined}>{c.definitions}</Link>
            <Link href={`/${locale}/franchise/qualite/risques${query}`} data-active={view === "risques" ? "true" : undefined}>{c.risks}</Link>
            <Link href={`/${locale}/franchise/qualite/incidents${query}`} data-active={view === "incidents" ? "true" : undefined}>{c.incidents}</Link>
          </nav>
          {view === "definitions" || view === "risques" || view === "recommandations" || view === "incidents" ? (
            <p className="client-access-note">{c.ruleModelsLead}</p>
          ) : null}
          <div className="client-table-wrap">
            <table className="client-space-table">
              <thead><tr><th>{c.folder}</th><th>{c.type}</th><th>{c.state}</th><th>{c.nextAction}</th><th>{c.action}</th></tr></thead>
              <tbody>
                {view === "actions" ? (
                  demo.corrective.length === 0 ? (
                    <tr><td colSpan={5}>{c.emptyCorrective}</td></tr>
                  ) : demo.corrective.map((row) => (
                    <tr key={row.id}>
                      <td>{row.title}</td>
                      <td>{c.corrective}</td>
                      <td><span className="client-status-chip" data-tone="peach">{row.status}</span></td>
                      <td>{row.due}</td>
                      <td><Cta href={`/${locale}/franchise/gouvernance${query}`} soft>{c.open}</Cta></td>
                    </tr>
                  ))
                ) : view === "anomalies" || view === "recommandations" || view === "opportunites" || view === "definitions" || view === "risques" || view === "incidents" ? (
                  pagedSupervision.rows.length === 0 ? (
                    <tr><td colSpan={5}>{supervisionEmpty}</td></tr>
                  ) : pagedSupervision.rows.map((row) => (
                    <tr key={row.id}>
                      <td>{row.title}</td>
                      <td>{row.meta ?? row.status}</td>
                      <td><span className="client-status-chip">{row.status}</span></td>
                      <td>—</td>
                      <td><Cta href={row.href} soft>{c.open}</Cta></td>
                    </tr>
                  ))
                ) : pagedQuality.rows.length === 0 ? (
                  <tr><td colSpan={5}>{c.emptyQuality}</td></tr>
                ) : pagedQuality.rows.map((row) => (
                  <tr key={row.id}>
                    <td>{row.title}</td>
                    <td>{row.type}</td>
                    <td><span className="client-status-chip" data-tone={row.tone}>{row.status}</span></td>
                    <td>{row.next}</td>
                    <td><Cta href={`/${locale}/franchise/gouvernance${query}`} soft>{c.open}</Cta></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {view === "actions" ? null : <PaginationNav path={qualityPath} query={query} page={supervision ? pagedSupervision.page : pagedQuality.page} pageCount={supervision ? pagedSupervision.pageCount : pagedQuality.pageCount} label={c.toExamine} />}
        </article>
        <article className="client-card">
          <header><h2>{c.treatItem}</h2></header>
          {view === "definitions" && libraryId && demo.canWrite ? (
            <FranchiseAnomalyDefinitionForm locale={locale} libraryId={libraryId} organizationId={organizationId || organizationIdFromQuery(query) || null} />
          ) : view === "risques" && libraryId && demo.canWrite ? (
            <FranchiseRiskDefinitionForm locale={locale} libraryId={libraryId} organizationId={organizationId || organizationIdFromQuery(query) || null} />
          ) : view === "recommandations" && libraryId && demo.canWrite ? (
            <FranchiseRecommendationDefinitionForm locale={locale} libraryId={libraryId} organizationId={organizationId || organizationIdFromQuery(query) || null} services={services ?? []} anomalies={demo.definitions} />
          ) : view === "incidents" && demo.canWrite ? (
            <>
              <p>{c.openingClientOnly}</p>
              <FranchiseIncidentInstructForm locale={locale} organizationId={organizationId || organizationIdFromQuery(query) || null} incidents={demo.incidents} />
            </>
          ) : (
            <>
              <p>{c.treatLead}</p>
              <ol className="franchise-process">
                {steps.map((step, index) => (
                  <li key={step.t}><span className="client-num">{index + 1}</span><span><strong>{step.t}</strong><small>{step.d}</small></span></li>
                ))}
              </ol>
              <p className="franchise-warning" role="note">{c.noSelf}</p>
              <Link href={`/${locale}/franchise/gouvernance${query}`} className="franchise-tool">{c.seeTrace}</Link>
            </>
          )}
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function PerformanceBoard({ locale, query, mandateName, view, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-treat">
        {demo.pipeline.slice(0, 3).map((item) => (
          <Link key={item.id} href={`/${locale}/franchise/performance${query}`} className="franchise-kpi-tile" data-tone={item.tone}>
            <span className="franchise-kpi-icon" data-tone={item.tone}><FileText className="size-4" aria-hidden /></span>
            <span><strong>{item.title}</strong><small>{item.detail}</small></span>
            <em className="client-status-chip" data-tone={item.tone}>{item.status}</em>
          </Link>
        ))}
      </section>
      <section className="franchise-workbench">
        <article className="client-card">
          <nav className="franchise-inspector-tabs" aria-label={c.objectives}>
            <Link href={`/${locale}/franchise/performance${query}`} data-active={!view ? "true" : undefined}>{c.objectives}</Link>
            <Link href={`/${locale}/franchise/performance/indicateurs${query}`} data-active={view === "indicateurs" ? "true" : undefined}>{c.object}</Link>
            <Link href={`/${locale}/franchise/performance/reseau${query}`} data-active={view === "reseau" ? "true" : undefined}>{c.netPeople}</Link>
            <Link href={`/${locale}/franchise/performance/tendances${query}`} data-active={view === "tendances" ? "true" : undefined}>{c.alerts}</Link>
          </nav>
          <div className="client-table-wrap">
            <table className="client-space-table">
              <thead><tr><th>{c.object}</th><th>{c.state}</th><th>{c.nextAction}</th><th>{c.action}</th></tr></thead>
              <tbody>
                {view === "tendances" ? (
                  demo.quality.length === 0 ? <tr><td colSpan={4}>{c.emptyQuality}</td></tr> : demo.quality.map((row) => (
                    <tr key={row.id}><td>{row.title}</td><td><span className="client-status-chip" data-tone={row.tone}>{row.status}</span></td><td>{row.next}</td><td><Cta href={`/${locale}/franchise/qualite${query}`} soft>{c.open}</Cta></td></tr>
                  ))
                ) : view === "reseau" ? (
                  demo.people.length === 0 ? <tr><td colSpan={4}>{c.emptyPeople}</td></tr> : demo.people.map((row) => (
                    <tr key={row.id}><td>{row.name}</td><td><span className="client-status-chip" data-tone={row.tone}>{row.status}</span></td><td>{row.next}</td><td><Cta href={`/${locale}/franchise/fournisseurs/${row.id}${query}`} soft>{c.openFolder}</Cta></td></tr>
                  ))
                ) : view === "indicateurs" && demo.corrective.length ? (
                  demo.corrective.map((row) => (
                    <tr key={row.id}><td>{row.title}</td><td><span className="client-status-chip" data-tone="peach">{row.status}</span></td><td>{row.due}</td><td><Cta href={`/${locale}/franchise/qualite/actions${query}`} soft>{c.open}</Cta></td></tr>
                  ))
                ) : demo.performance.length === 0 ? (
                  <tr><td colSpan={4}>{c.emptyPerformance}</td></tr>
                ) : demo.performance.map((row) => (
                  <tr key={row.id}>
                    <td>{row.title}</td>
                    <td><span className="client-status-chip" data-tone="sky">{row.status}</span></td>
                    <td>{row.next}</td>
                    <td><Cta href={`/${locale}/franchise/performance${query}`} soft>{c.open}</Cta></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </article>
        <article className="client-card">
          <header><h2>{c.alerts}</h2></header>
          <ul className="franchise-dot-list">
            {demo.attention.map((item) => (
              <li key={item.id}><span className="franchise-dot" data-tone="peach" /><strong>{item.title}</strong><Cta href={item.href} soft>{c.open}</Cta></li>
            ))}
          </ul>
          <p className="client-access-note">{c.noOut}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function FollowupsBoard({ locale, query, mandateName, view, page, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const followPath = view ? `/${locale}/franchise/relances/${view}` : `/${locale}/franchise/relances`;
  const pagedFollowups = paginate(demo.followups, page);
  const pagedJournal = paginate(demo.journal, page);
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-workbench">
        <article className="client-card">
          <nav className="franchise-inspector-tabs" aria-label={c.due}>
            <Link href={`/${locale}/franchise/relances${query}`} data-active={!view ? "true" : undefined}>{c.due}</Link>
            <Link href={`/${locale}/franchise/relances/pipeline${query}`} data-active={view === "pipeline" ? "true" : undefined}>{c.rule}</Link>
            <Link href={`/${locale}/franchise/relances/historique${query}`} data-active={view === "historique" ? "true" : undefined}>{c.govHistory}</Link>
          </nav>
          <div className="client-table-wrap">
            {view === "historique" ? (
              <table className="client-space-table">
                <thead><tr><th>{c.document}</th><th>{c.govHistory}</th><th>{c.dueWhen}</th></tr></thead>
                <tbody>
                  {pagedJournal.rows.length === 0 ? (
                    <tr><td colSpan={3}>{c.emptyFollowups}</td></tr>
                  ) : pagedJournal.rows.map((row) => (
                    <tr key={row.id}>
                      <td>{row.doc}</td>
                      <td>{row.event}</td>
                      <td>{row.date}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <table className="client-space-table">
                <thead><tr><th>{c.profile}</th><th>{c.dueWhen}</th><th>{c.followAction}</th><th>{c.action}</th></tr></thead>
                <tbody>
                  {pagedFollowups.rows.length === 0 ? (
                    <tr><td colSpan={4}>{c.emptyFollowups}</td></tr>
                  ) : pagedFollowups.rows.map((row) => (
                    <tr key={row.id}>
                      <td><span className="franchise-row-title"><span className="franchise-kpi-icon" data-tone={row.tone}><Bell className="size-4" aria-hidden /></span>{row.title}</span></td>
                      <td><span className="client-status-chip" data-tone={row.tone}>{row.due}</span></td>
                      <td>{row.action}</td>
                      <td><Cta href={row.href ?? `/${locale}/franchise/relances${query}#relances`} soft>{c.open}</Cta></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
          <PaginationNav path={followPath} query={query} page={view === "historique" ? pagedJournal.page : pagedFollowups.page} pageCount={view === "historique" ? pagedJournal.pageCount : pagedFollowups.pageCount} label={c.due} />
        </article>
        <article className="client-card">
          <header><h2>{c.rule}</h2></header>
          <p>{c.ruleLead}</p>
          <Link href={`/${locale}/franchise/relances${query}#relances`} className="franchise-tool franchise-tool-primary">{c.proposeRule}</Link>
          {view === "pipeline" ? <p className="client-access-note">{c.ruleLead}</p> : null}
          <p className="client-access-note">{c.scopeNote}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function GovernanceBoard({ locale, query, mandateName, view, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-workbench">
        <article className="client-card">
          <header className="client-priority-head">
            <div>
              <h2>{c.decisions}</h2>
              <p>{c.decisionsLead}</p>
            </div>
          </header>
          <nav className="franchise-inspector-tabs" aria-label={c.decisions}>
            <Link href={`/${locale}/franchise/gouvernance${query}`} data-active={!view ? "true" : undefined}>{c.toPrepare}</Link>
            <Link href={`/${locale}/franchise/gouvernance/approbations${query}`} data-active={view === "approbations" ? "true" : undefined}>{c.inValidation}</Link>
            <Link href={`/${locale}/franchise/gouvernance/perimetre${query}`} data-active={view === "perimetre" ? "true" : undefined}>{c.authorized}</Link>
            <Link href={`/${locale}/franchise/gouvernance/historique${query}`} data-active={view === "historique" ? "true" : undefined}>{c.govHistory}</Link>
          </nav>
          <div className="client-table-wrap" id="decisions">
            <table className="client-space-table">
              <thead><tr><th>{c.object}</th><th>{c.type}</th><th>{c.state}</th><th>{c.action}</th></tr></thead>
              <tbody>
                {demo.decisions.length === 0 ? (
                  <tr><td colSpan={4}>{c.emptyDecisions}</td></tr>
                ) : demo.decisions.map((row) => (
                  <tr key={row.id}>
                    <td>{row.title}</td>
                    <td>{row.type}</td>
                    <td><span className="client-status-chip" data-tone="peach">{row.status}</span></td>
                    <td><Cta href={`/${locale}/franchise/gouvernance${query}#gouvernance`} soft>{c.prepare}</Cta></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <header className="franchise-section-head"><h2>{c.mandates}</h2></header>
          <ul className="client-feed">
            {demo.mandates.map((row) => (
              <li key={row.id}><span><strong>{row.title}</strong><small>{row.type}</small></span><em className="client-status-chip" data-tone="mint">{row.status}</em></li>
            ))}
          </ul>
        </article>
        <article className="client-card">
          <header><h2>{c.prepareDec}</h2></header>
          <p>{c.prepareDecLead}</p>
          {demo.decisions[0] ? (
            <ul className="client-feed">
              <li><span><strong>{demo.decisions[0].title}</strong><small>{demo.decisions[0].type}</small></span><em className="client-status-chip" data-tone="peach">{demo.decisions[0].status}</em></li>
            </ul>
          ) : <p className="franchise-empty-panel">{c.emptyDecisions}</p>}
          <Link href={`/${locale}/franchise/documents${query}`} className="franchise-tool franchise-tool-primary">{c.pieces}</Link>
          <p className="client-access-note">{c.autoVal}</p>
          <header className="franchise-section-head"><h2>{c.govHistory}</h2></header>
          <ol className="franchise-activity">
            {demo.govHistory.map((item) => (
              <li key={item.id}><span className="franchise-dot" data-tone="violet" /><span><strong>{item.title}</strong><small>{item.actor}</small></span></li>
            ))}
          </ol>
          <p className="client-access-note">{c.auditNote}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function FranchiseFinanceBoard({ locale, query, mandateName, view, board, libraryId, organizationId }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const statements = demo.finance.filter((row) => row.kind !== "entryFee" && row.kind !== "payout" && row.title !== c.entryFee);
  const fees = demo.finance.filter((row) => row.kind === "entryFee" || row.title === c.entryFee);
  const payouts = demo.finance.filter((row) => row.kind === "payout");
  const preStatements = demo.finance.filter((row) => row.kind === "preStatement");
  const rows = view === "volume" ? demo.volume
    : view === "droit-entree" ? fees
      : view === "paiements" ? payouts
        : view === "pre-releve" ? preStatements
          : statements.length ? statements : demo.finance;
  const empty = view === "volume" ? c.emptyVolume
    : view === "droit-entree" ? c.emptyFinance
      : view === "paiements" ? c.emptyPayments
        : view === "pre-releve" ? c.emptyPreStatement
          : c.emptyFinance;
  const heading = view === "volume" ? c.volume
    : view === "droit-entree" ? c.entryFee
      : view === "paiements" ? c.payments
        : view === "pre-releve" ? c.preStatement
          : c.finItems;
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <section className="franchise-treat">
        <article className="franchise-kpi-tile" data-tone="sky">
          <span className="franchise-kpi-icon" data-tone="sky"><FileText className="size-4" aria-hidden /></span>
          <span><strong>{c.docsExamine}</strong><small>{demo.finance[0]?.title ?? c.emptyFinance}</small></span>
        </article>
        <article className="franchise-kpi-tile" data-tone="peach">
          <span className="franchise-kpi-icon" data-tone="peach"><ShieldCheck className="size-4" aria-hidden /></span>
          <span><strong>{c.valsPending}</strong><small>{demo.finance[1]?.title ?? c.emptyFinance}</small></span>
        </article>
        <article className="franchise-kpi-tile" data-tone="mint">
          <span className="franchise-kpi-icon" data-tone="mint"><FileText className="size-4" aria-hidden /></span>
          <span><strong>{c.statements}</strong><small>{demo.finance.find((row) => row.amount)?.title ?? demo.finance[2]?.title ?? c.emptyFinance}</small></span>
        </article>
      </section>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{heading}</h2></header>
          <nav className="franchise-inspector-tabs" aria-label={c.finItems}>
            <Link href={`/${locale}/franchise/finance${query}`} data-active={!view ? "true" : undefined}>{c.statements}</Link>
            <Link href={`/${locale}/franchise/finance/pre-releve${query}`} data-active={view === "pre-releve" ? "true" : undefined}>{c.preStatement}</Link>
            <Link href={`/${locale}/franchise/finance/paiements${query}`} data-active={view === "paiements" ? "true" : undefined}>{c.payments}</Link>
            <Link href={`/${locale}/franchise/finance/volume${query}`} data-active={view === "volume" ? "true" : undefined}>{c.volume}</Link>
            <Link href={`/${locale}/franchise/finance/droit-entree${query}`} data-active={view === "droit-entree" ? "true" : undefined}>{c.entryFee}</Link>
          </nav>
          {view === "volume" ? (
            <>
              {rows.length === 0 ? <p>{empty}</p> : (
                <ul className="client-feed">
                  {rows.map((row) => (
                    <li key={row.id}><span><strong>{row.title}</strong><small>{"meta" in row ? row.meta : row.status}</small></span><em className="client-status-chip">{row.status}</em></li>
                  ))}
                </ul>
              )}
              <p className="client-access-note">{c.proposeVolume}</p>
              {demo.canWrite && libraryId ? (
                <FranchiseVolumeProposeForm
                  locale={locale}
                  libraryId={libraryId}
                  organizationId={organizationId || organizationIdFromQuery(query) || null}
                  skus={demo.volume.filter((row) => row.status === "ACTIVE").map((row) => ({ id: row.id, title: row.title }))}
                />
              ) : null}
            </>
          ) : (
            <div className="client-table-wrap">
              <table className="client-space-table">
                <thead><tr><th>{c.document}</th><th>{c.linked}</th><th>{c.state}</th><th>{c.authReq}</th></tr></thead>
                <tbody>
                  {rows.length === 0 ? (
                    <tr><td colSpan={4}>{empty}</td></tr>
                  ) : rows.map((row) => (
                    <tr key={row.id}>
                      <td>{row.title}</td>
                      <td>{"object" in row ? row.object : "—"}</td>
                      <td><span className="client-status-chip" data-tone={"tone" in row ? row.tone : "sky"}>{row.status}</span></td>
                      <td>{"auth" in row ? row.auth : "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </article>
        <article className="client-card">
          <header><h2>{c.understand}</h2></header>
          <p>{c.understandLead}</p>
          <p>{demo.finance.some((row) => row.amount) ? c.yourShareLead : c.noAmount}</p>
          {view === "paiements" || view === "pre-releve" ? <p className="client-access-note">{c.paymentPlatformNote}</p> : <p className="client-access-note">{c.goodToKnowLead}</p>}
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function DocumentsBoard({ locale, query, mandateName, view, search, page, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const n = libraryCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const needle = (search ?? "").trim().toLocaleLowerCase();
  const filtered = (view === "renouvellements" ? demo.renewals : demo.documents).filter((row) => !needle || `${row.title} ${row.owner} ${row.status}`.toLocaleLowerCase().includes(needle));
  const paged = paginate(filtered, page);
  const rows = paged.rows;
  const org = organizationIdFromQuery(query);
  const docsPath = view === "renouvellements" ? `/${locale}/franchise/documents/renouvellements` : `/${locale}/franchise/documents`;
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <div className="franchise-toolbar">
        <form action={`/${locale}/franchise/documents`} method="get" className="franchise-search">
          {org ? <input type="hidden" name="organizationId" value={org} /> : null}
          <label><span className="sr-only">{c.search}</span><input name="q" defaultValue={search} placeholder={c.search} /></label>
          <button type="submit" className="franchise-scope-chip">{c.search}</button>
        </form>
        <Link href={`/${locale}/franchise/documents${query}`} className="franchise-tool franchise-tool-primary" data-active={!view ? "true" : undefined}>{n.documentsTitle}</Link>
        <Link href={`/${locale}/franchise/documents/renouvellements${query}`} className="franchise-tool" data-active={view === "renouvellements" ? "true" : undefined}>{n.renewals}</Link>
      </div>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{view === "renouvellements" ? n.renewals : n.documentsTitle}</h2></header>
          <div className="client-table-wrap">
            <table className="client-space-table">
              <thead><tr><th>{c.document}</th><th>{c.owner}</th><th>{c.state}</th><th>{c.documentKind}</th><th>{c.action}</th></tr></thead>
              <tbody>
                {rows.length === 0 ? (
                  <tr><td colSpan={5}>{view === "renouvellements" ? c.emptyRenewals : n.noDocuments}</td></tr>
                ) : rows.map((row) => (
                  <tr key={row.id}>
                    <td>{row.title}{"due" in row && row.due ? ` · ${row.due}` : ""}</td>
                    <td>{row.owner}</td>
                    <td><span className="client-status-chip" data-tone="violet">{row.status}</span></td>
                    <td>{row.kind === "renewal" ? c.renewal : c.evidence}</td>
                    <td><Cta href={row.href} soft>{c.open}</Cta></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <PaginationNav path={docsPath} query={query} page={paged.page} pageCount={paged.pageCount} label={n.documentsTitle} />
        </article>
        <article className="client-card">
          <header><h2>{n.renewals}</h2></header>
          <p>{n.emptyDocumentsLead}</p>
          <p className="client-access-note">{c.scopeNote}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}

export function MessagesBoard({ locale, query, mandateName, view, search, page, board }: SpaceBoardProps) {
  const c = franchiseCopy(locale);
  const n = libraryCopy(locale);
  const demo = resolveBoard({ locale, query, board });
  const needle = (search ?? "").trim().toLocaleLowerCase();
  const filteredThreads = demo.messages.filter((row) => !needle || `${row.title} ${row.meta}`.toLocaleLowerCase().includes(needle));
  const filteredNotices = demo.notifications.filter((row) => !needle || `${row.title} ${row.meta}`.toLocaleLowerCase().includes(needle));
  const pagedThreads = paginate(filteredThreads, page);
  const pagedNotices = paginate(filteredNotices, page);
  const threads = pagedThreads.rows;
  const notices = pagedNotices.rows;
  const org = organizationIdFromQuery(query);
  return (
    <main className="client-page">
      <Banner locale={locale} query={query} mandateName={mandateName} />
      <div className="franchise-toolbar">
        <form action={`/${locale}/franchise/${view === "notifications" ? "notifications" : "messages"}`} method="get" className="franchise-search">
          {org ? <input type="hidden" name="organizationId" value={org} /> : null}
          <label><span className="sr-only">{c.search}</span><input name="q" defaultValue={search} placeholder={c.search} /></label>
          <button type="submit" className="franchise-scope-chip">{c.search}</button>
        </form>
        <Link href={`/${locale}/franchise/messages${query}`} className="franchise-tool franchise-tool-primary" data-active={!view || view !== "notifications" ? "true" : undefined}>{n.messagesTitle}</Link>
        <Link href={`/${locale}/franchise/notifications${query}`} className="franchise-tool" data-active={view === "notifications" ? "true" : undefined}>{n.notifications}</Link>
      </div>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{view === "notifications" ? n.notifications : n.messagesTitle}</h2></header>
          {view === "notifications" ? (
            notices.length === 0 ? <p className="franchise-empty-panel">{c.emptyNotifications}</p> : (
              <ul className="client-feed">
                {notices.map((row) => (
                  <li key={row.id}><Bell className="size-4" aria-hidden /><span><strong>{row.title}</strong><small>{row.meta}</small></span><Cta href={row.href} soft>{c.open}</Cta></li>
                ))}
              </ul>
            )
          ) : threads.length === 0 ? <p className="franchise-empty-panel">{n.noMessages}</p> : (
            <ul className="client-feed">
              {threads.map((row) => (
                <li key={row.id}><span><strong>{row.title}</strong><small>{row.meta}</small></span><Cta href={row.href} soft>{c.open}</Cta></li>
              ))}
            </ul>
          )}
          <PaginationNav path={`/${locale}/franchise/${view === "notifications" ? "notifications" : "messages"}`} query={query} page={view === "notifications" ? pagedNotices.page : pagedThreads.page} pageCount={view === "notifications" ? pagedNotices.pageCount : pagedThreads.pageCount} label={n.messagesTitle} />
        </article>
        <article className="client-card">
          <header><h2>{c.messageThread}</h2></header>
          <p>{n.emptyMessagesLead}</p>
          <p className="client-access-note">{c.scopeNote}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={mandateName} />
      </section>
    </main>
  );
}
