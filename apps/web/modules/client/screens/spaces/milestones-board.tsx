import Link from "next/link";
import { FileText, Shield, Users } from "lucide-react";
import type { ReactNode } from "react";
import { canApplyClientSpaceDemo, demoClientSpaces } from "@/modules/client/data/spaces/demo";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { MilestoneDecisionForm } from "@/modules/client/screens/missions/milestone-decision-form";
import type { MissionMessages } from "@/modules/client/screens/missions/messages";
import type { ContractMissionDashboard } from "@/modules/shared/lib/contracts-missions/model";
import { AssistanceCue } from "@/modules/client/screens/diagnostics/assistance-cue";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

function toneFor(state: "done" | "current" | "todo") {
  if (state === "done") return "mint" as const;
  if (state === "current") return "violet" as const;
  return "peach" as const;
}

function milestoneState(status: string): "done" | "current" | "todo" {
  if (status === "ACCEPTED" || status === "DONE" || status === "COMPLETED") return "done";
  if (status === "SUBMITTED" || status === "IN_REVIEW" || status === "IN_PROGRESS") return "current";
  return "todo";
}

export function JalonsBoard({
  locale,
  query,
  organizationName,
  mission,
  messages,
  assistanceHref,
  children,
}: {
  locale: Locale;
  query: string;
  organizationName?: string | null;
  mission: ContractMissionDashboard["missions"][number] | null;
  messages: MissionMessages;
  assistanceHref?: string;
  children?: ReactNode;
}) {
  const c = spaceCopy(locale);
  const demo = demoClientSpaces(locale, query);
  const preferDemo = canApplyClientSpaceDemo(organizationName ?? null) && (!mission || mission.milestones.length === 0);
  const jalons = preferDemo
    ? demo.jalons
    : (mission?.milestones ?? []).map((item) => ({
        id: item.id,
        title: item.title,
        due: item.dueAt ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(item.dueAt)) : "—",
        status: item.status,
        state: milestoneState(item.status),
      }));
  const selected = jalons.find((item) => item.state === "current") ?? jalons[0] ?? null;
  const selectedLive = mission?.milestones.find((item) => item.id === selected?.id) ?? null;
  const files = preferDemo ? demo.jalonFiles : (mission?.deliverables ?? []).map((item) => ({
    id: item.id,
    title: item.label,
    file: item.label,
    kind: "file" as const,
    scan: item.proofScanStatus === "CLEAN" ? "ok" as const : "wait" as const,
    href: `/${locale}/client/documents${query}`,
  }));
  const started = mission?.startedAt
    ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(mission.startedAt))
    : "—";
  const ended = mission?.completedAt
    ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(mission.completedAt))
    : "—";

  return (
    <main className="client-page">
      <article className="client-card client-mission-mast">
        <div>
          <h2>{organizationName ?? (locale === "ar" ? "المهمة الجارية" : "Mission en cours")}</h2>
          <p>{c.misLead}</p>
          <div className="client-offer-actions">
            <span className="client-status-chip" data-tone="mint">{c.contractSigned}</span>
            <span className="client-access-note"><Shield className="size-4" aria-hidden />{c.immutableVersion}</span>
            {mission ? <Link href={`/${locale}/client/missions/${mission.id}${query}`} className="client-text-link">{c.seeAmendment}</Link> : null}
          </div>
        </div>
        <div>
          <span className="client-status-chip" data-tone="mint">{c.inProgress}</span>
          <p dir="ltr">{started} — {ended}</p>
        </div>
        <div>
          <strong>{c.participants}</strong>
          <p><Users className="size-4" aria-hidden /> {c.yourCompany} · {c.matriciaTeam} · {c.partners}</p>
        </div>
      </article>
      {assistanceHref ? <AssistanceCue locale={locale} href={assistanceHref} context="milestone" /> : null}
      <nav className="client-tabs" aria-label={c.jalonsTitle}>
        <a href="#jalons" aria-current="page">{c.tabJalons}</a>
        <Link href={mission ? `/${locale}/client/missions/${mission.id}${query}` : `/${locale}/client/missions${query}`}>{c.tabMission}</Link>
        <Link href={`/${locale}/client/documents${query}`}>{c.docsTab}</Link>
        <Link href={`/${locale}/messagerie${query}`}>{c.messagesTab}</Link>
        <a href="#jalon-history">{c.tabHistory}</a>
      </nav>
      <section className="client-dispute-layout" id="jalons">
        <article className="client-card">
          <ol className="client-mediation">
            {jalons.map((item, index) => (
              <li key={item.id} data-state={item.state}>
                <span>
                  <strong>{index + 1}. {item.title}</strong>
                  <small>{c.dueOn}: {item.due}</small>
                </span>
                <span className="client-status-chip" data-tone={toneFor(item.state)}>{item.status}</span>
              </li>
            ))}
          </ol>
        </article>
        <article className="client-card">
          {selected ? (
            <>
              <header className="client-priority-head">
                <div>
                  <h2>{selected.title}</h2>
                  <p>{c.dueOn}: {selected.due}</p>
                </div>
                <span className="client-status-chip" data-tone={toneFor(selected.state)}>{selected.status}</span>
              </header>
              <h3>{c.deliverablesOf}</h3>
              <div className="client-table-wrap">
                <table className="client-space-table">
                  <thead><tr><th>{c.docsTitle}</th><th>{locale === "ar" ? "ملف" : "Fichier"}</th><th>{locale === "ar" ? "الفحص" : "Scan"}</th><th /></tr></thead>
                  <tbody>
                    {files.map((file) => (
                      <tr key={file.id}>
                        <td><span className="client-doc-cell"><FileText className="size-4" aria-hidden />{file.title}</span></td>
                        <td>{file.file}</td>
                        <td><span className="client-status-chip" data-tone={file.scan === "ok" ? "mint" : "peach"}>{file.scan === "ok" ? c.scanOk : c.scanWait}</span></td>
                        <td><Link href={file.href} className="client-text-link">{c.open}</Link></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <Link href={`/${locale}/client/documents${query}`} className="client-ghost-link">{c.addFile}</Link>
              <div id="jalon-history" className="client-next-action">
                <h3>{c.commentsOnJalon}</h3>
                {selectedLive ? <MilestoneDecisionForm milestone={selectedLive} locale={locale} messages={messages} /> : (
                  <div className="client-offer-actions">
                    <Link href={`/${locale}/client/missions${query}`} className="client-cta">{c.acceptJalon}</Link>
                    <Link href={`/${locale}/messagerie${query}`} className="client-soft-link">{c.requestChanges}</Link>
                    <Link href={`/${locale}/client/litiges${query}`} className="client-ghost-link">{c.rejectWithReason}</Link>
                  </div>
                )}
              </div>
            </>
          ) : <p>{messages.empty}</p>}
        </article>
      </section>
      {children}
    </main>
  );
}
