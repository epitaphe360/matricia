import Link from "next/link";
import { ArrowRight, Bell, Calendar, FileText, MessageSquare } from "lucide-react";
import type { ReactNode } from "react";
import { canApplyClientSpaceDemo, demoClientSpaces } from "@/modules/client/data/spaces/demo";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { JourneyGlyph } from "@/modules/shared/ui/journey-glyph";
import type { ContractMissionDashboard } from "@/modules/shared/lib/contracts-missions/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

function Cta({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link href={href} className="client-ghost-link">
      {children}
      <ArrowRight className="size-4 rtl:rotate-180" aria-hidden />
    </Link>
  );
}

export function FollowBoard({
  locale,
  query,
  organizationName,
  mission,
  children,
}: {
  locale: Locale;
  query: string;
  organizationName?: string | null;
  mission: ContractMissionDashboard["missions"][number] | null;
  children?: ReactNode;
}) {
  const c = spaceCopy(locale);
  const demo = demoClientSpaces(locale, query);
  const preferDemo = canApplyClientSpaceDemo(organizationName ?? null);
  const folders = mission
    ? [{ id: mission.id, title: organizationName ?? c.misTitle, status: mission.status, tone: "mint" as const, href: `/${locale}/client/missions/${mission.id}/jalons${query}` }]
    : preferDemo
      ? demo.requests.slice(0, 4).map((row) => ({ id: row.id, title: row.title, status: row.status, tone: row.tone, href: row.href }))
      : [];
  const steps = mission
    ? mission.milestones.map((item, index, all) => {
        const done = item.status === "ACCEPTED" || item.status === "DONE" || item.status === "COMPLETED";
        const current = !done && (index === 0 || all.slice(0, index).every((row) => row.status === "ACCEPTED" || row.status === "DONE" || row.status === "COMPLETED"));
        return { id: item.id, title: item.title, detail: item.status, state: (done ? "done" : current ? "current" : "todo") as "done" | "current" | "todo" };
      })
    : preferDemo
      ? demo.missions.steps
      : [];
  const offerHref = `/${locale}/client/demandes${query}`;
  const offers = preferDemo ? demo.compareOffers.slice(0, 2) : [];
  const files = preferDemo ? demo.missions.files : (mission?.deliverables ?? []).map((item) => ({
    id: item.id,
    title: item.label,
    href: `/${locale}/client/documents${query}`,
    kind: "file" as const,
  }));

  return (
    <main className="client-page">
      <section className="client-board client-board-compare">
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{c.treatNow}</h2>
            <Link href={`/${locale}/client/missions${query}`} className="client-text-link">{c.seeAll}</Link>
          </header>
          <ul className="client-feed">
            <li><Link href={`/${locale}/client/diagnostics${query}`}><span className="client-feed-icon" data-tone="peach"><FileText className="size-4" aria-hidden /></span><span>{c.resumeBilan}</span><em><span className="client-status-chip" data-tone="peach">{c.actionRequired}</span></em></Link></li>
            <li><Link href={offerHref}><span className="client-feed-icon" data-tone="violet"><FileText className="size-4" aria-hidden /></span><span>{c.compareOffers}</span><em><span className="client-status-chip" data-tone="violet">{c.inProgress}</span></em></Link></li>
            <li><Link href={mission ? `/${locale}/client/missions/${mission.id}/jalons${query}` : `/${locale}/client/missions${query}`}><span className="client-feed-icon" data-tone="sky"><FileText className="size-4" aria-hidden /></span><span>{c.examineDeliverableNow}</span><em><span className="client-status-chip" data-tone="sky">{c.awaiting}</span></em></Link></li>
            <li><Link href={`/${locale}/client/documents${query}`}><span className="client-feed-icon" data-tone="peach"><FileText className="size-4" aria-hidden /></span><span>{c.completePiece}</span><em><span className="client-status-chip" data-tone="peach">{c.toCompleteChip}</span></em></Link></li>
          </ul>
        </article>
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{c.foldersNow}</h2>
            <Link href={`/${locale}/client/missions${query}`} className="client-text-link">{c.seeAll}</Link>
          </header>
          {folders.length === 0 ? <p>{locale === "ar" ? "لا ملف جارٍ للعرض." : "Aucun dossier en cours à afficher."}</p> : (
            <ul className="client-feed">
              {folders.map((row) => (
                <li key={row.id}><Link href={row.href}><span className="client-feed-icon" data-tone={row.tone} /><span>{row.title}</span><em><span className="client-status-chip" data-tone={row.tone}>{row.status}</span></em></Link></li>
              ))}
            </ul>
          )}
        </article>
      </section>
      <article className="client-card">
        <header className="client-priority-head">
          <h2>{c.myRequestsMissions}</h2>
          <Cta href={mission ? `/${locale}/client/missions/${mission.id}${query}` : `/${locale}/client/missions${query}`}>{c.openTheFolder}</Cta>
        </header>
        <ol className="client-journey">
          {steps.map((step, index) => (
            <li key={step.id} data-state={step.state}><span><JourneyGlyph index={index} /></span><small>{step.title}</small></li>
          ))}
        </ol>
      </article>
      <article className="client-card">
        <header className="client-priority-head">
          <h2>{c.offersToCompare}</h2>
          <Link href={offerHref} className="client-text-link">{c.seeDetail}</Link>
        </header>
        {offers.length === 0 ? (
          <p>{c.compareLead}</p>
        ) : (
          <div className="client-table-wrap">
            <table className="client-space-table">
              <thead>
                <tr>
                  <th>{c.need}</th>
                  {offers.map((offer) => <th key={offer.slot}>{locale === "ar" ? `عرض ${offer.slot}` : `Offre ${offer.slot.toUpperCase()}`}</th>)}
                </tr>
              </thead>
              <tbody>
                <tr><th>{locale === "ar" ? "النطاق" : "Périmètre"}</th>{offers.map((offer) => <td key={`${offer.slot}-p`}>{offer.tagline}</td>)}</tr>
                <tr><th>{c.durationLabel}</th>{offers.map((offer) => <td key={`${offer.slot}-d`}>{offer.weeks} {locale === "ar" ? "أسابيع" : "semaines"}</td>)}</tr>
                <tr><th>{c.exclusions}</th>{offers.map((offer) => <td key={`${offer.slot}-e`}>{offer.exclusions[0]}</td>)}</tr>
              </tbody>
            </table>
          </div>
        )}
        <div className="client-next-action">
          <Link href={offerHref} className="client-cta">{c.nextDecision} : {c.compareCta}</Link>
        </div>
      </article>
      <section className="client-follow-triple">
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.documentsRenewals}</h2><Link href={`/${locale}/client/documents${query}`} className="client-text-link">{c.seeAll}</Link></header>
          <ul className="client-feed">
            {files.slice(0, 3).map((file) => (
              <li key={file.id}><Link href={file.href}><FileText className="size-4" aria-hidden /><span>{file.title}</span><em>{c.open}</em></Link></li>
            ))}
          </ul>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.nextDeadlines}</h2><Link href={`/${locale}/client/missions${query}`} className="client-text-link">{c.seeAll}</Link></header>
          <ul className="client-feed">
            {(mission?.milestones ?? []).slice(0, 3).map((item) => (
              <li key={item.id}><span className="client-feed-icon" data-tone="sky"><Calendar className="size-4" aria-hidden /></span><span>{item.title}</span><em>{c.comingSoon}</em></li>
            ))}
            {!mission && preferDemo ? demo.missions.steps.filter((step) => step.state !== "done").slice(0, 3).map((step) => (
              <li key={step.id}><span className="client-feed-icon" data-tone="sky"><Calendar className="size-4" aria-hidden /></span><span>{step.title}</span><em>{c.comingSoon}</em></li>
            )) : null}
          </ul>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.messagesNotifs}</h2><Link href={`/${locale}/messagerie${query}`} className="client-text-link">{c.seeAll}</Link></header>
          <ul className="client-feed">
            <li><Link href={`/${locale}/messagerie${query}`}><span className="client-feed-icon" data-tone="violet"><MessageSquare className="size-4" aria-hidden /></span><span>{c.threadTitle}</span><em><Bell className="size-4" aria-hidden /></em></Link></li>
            <li><Link href={`/${locale}/notifications${query}`}><span className="client-feed-icon" data-tone="peach"><Bell className="size-4" aria-hidden /></span><span>{c.notif}</span><em>{c.open}</em></Link></li>
          </ul>
        </article>
      </section>
      {children}
    </main>
  );
}
