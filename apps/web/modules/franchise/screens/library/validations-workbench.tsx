import Link from "next/link";
import { FileText, MessageSquare, Send, BookOpen } from "lucide-react";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { catalogStatusLabel, type FranchiseCatalogRow, type FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { KindChip, MandateBanner, StatusChip, nextAction } from "./library-boards";
import { FranchiseMandateRail } from "./library-chrome";
import { FranchisePublishReleaseForm } from "./catalog-commands";

export const FRANCHISE_VALIDATION_BUCKETS: Record<string, string[] | null> = {
  brouillons: ["DRAFT"],
  "en-cours": ["IN_REVIEW", "FRANCHISE_REVIEW", "CENTRAL_REVIEW", "LOCAL_TEST"],
  corrections: ["REJECTED", "CHANGES_REQUESTED"],
  approuves: ["APPROVED"],
  publications: ["PUBLISHED"],
  historique: null,
};

const bucketIcons = [FileText, Send, MessageSquare, BookOpen] as const;
const bucketTones = ["violet", "peach", "mint", "sky"] as const;

function bucketLabel(key: string, locale: Locale) {
  const c = libraryCopy(locale);
  if (key === "brouillons") return c.bucketDrafts;
  if (key === "en-cours") return c.bucketReview;
  if (key === "corrections") return c.bucketCorrections;
  if (key === "approuves") return c.bucketApproved;
  if (key === "publications") return c.bucketPublished;
  return c.bucketHistory;
}

function filterRows(rows: FranchiseCatalogRow[], bucket: string | null) {
  const allowed = bucket ? FRANCHISE_VALIDATION_BUCKETS[bucket] : undefined;
  if (!bucket || allowed === undefined) return rows;
  if (allowed === null) return rows;
  return rows.filter((item) => allowed.includes(item.status));
}

export function FranchiseValidationsWorkbench({
  locale,
  query,
  workspace,
  bucket = null,
  commandIdentity,
  organizationId = null,
}: {
  locale: Locale;
  query: string;
  workspace: FranchiseLibraryWorkspace;
  bucket?: string | null;
  commandIdentity?: { idempotencyKey: string; correlationId: string };
  organizationId?: string | null;
}) {
  const c = libraryCopy(locale);
  const all = [...workspace.services, ...workspace.questionnaires, ...workspace.rules];
  const rows = filterRows(all, bucket);
  const counts = {
    brouillons: filterRows(all, "brouillons").length,
    "en-cours": filterRows(all, "en-cours").length,
    corrections: filterRows(all, "corrections").length,
    publications: filterRows(all, "publications").length,
  };
  const kpis = [
    { key: "brouillons", label: c.bucketDrafts, value: counts.brouillons, help: c.draftsHelp },
    { key: "en-cours", label: c.bucketReview, value: counts["en-cours"], help: c.inReviewHelp },
    { key: "corrections", label: c.bucketCorrections, value: counts.corrections, help: c.returnsHelp },
    { key: "publications", label: c.bucketPublished, value: counts.publications, help: c.publishedHelp },
  ] as const;
  return (
    <main className="client-page">
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <section className="franchise-treat">
        {kpis.map((item, index) => {
          const Icon = bucketIcons[index] ?? FileText;
          return (
            <Link key={item.key} href={`/${locale}/franchise/validations/${item.key}${query}`} className="franchise-kpi-tile" data-tone={bucketTones[index]}>
              <span className="franchise-kpi-icon"><Icon className="size-4" aria-hidden /></span>
              <span>
                <strong>{item.label}</strong>
                <small><bdi dir="ltr">{item.value}</bdi> · {item.help}</small>
              </span>
            </Link>
          );
        })}
      </section>
      <ol className="franchise-mini-pipe">
        {c.validationSteps.map(([title, text], index) => (
          <li key={title} data-active={index === 0 ? "true" : undefined}>
            <em>{index + 1}</em>
            <strong>{title}</strong>
            <small>{text}</small>
          </li>
        ))}
      </ol>
      <section className="franchise-workbench">
        <article className="client-card">
          <header><h2>{c.validationsTitle}</h2></header>
          <ul className="franchise-bucket-nav">
            {Object.keys(FRANCHISE_VALIDATION_BUCKETS).map((key) => (
              <li key={key}>
                <Link href={`/${locale}/franchise/validations/${key}${query}`} data-active={bucket === key ? "true" : undefined}>
                  <span>{bucketLabel(key, locale)}</span>
                  <small dir="ltr">{key === "historique" ? all.length : filterRows(all, key).length}</small>
                </Link>
              </li>
            ))}
          </ul>
        </article>
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{bucket ? bucketLabel(bucket, locale) : c.queue}</h2>
          </header>
          {rows.length === 0 ? <p>{c.emptyQueue}</p> : (
            <div className="client-table-wrap client-compare">
              <table className="client-space-table">
                <thead>
                  <tr>
                    <th>{c.element}</th>
                    <th>{c.kind}</th>
                    <th>{c.version}</th>
                    <th>{c.validation}</th>
                    <th>{c.next}</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((item) => (
                    <tr key={`${item.kind}-${item.id}`}>
                      <td><strong>{item.title}</strong></td>
                      <td><KindChip kind={item.kind} locale={locale} /></td>
                      <td>{item.versionLabel ?? "—"}</td>
                      <td><StatusChip status={item.status} locale={locale} /></td>
                      <td><Link href={item.href}>{nextAction(item.status, locale)}</Link></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {workspace.releases.length > 0 ? (
            <ul className="client-feed">
              {workspace.releases.map((item) => (
                <li key={item.id}><span><strong dir="ltr">{item.key}</strong><small>{catalogStatusLabel(item.status, locale)}</small></span></li>
              ))}
            </ul>
          ) : null}
          {commandIdentity && (bucket === "approuves" || bucket === "publications" || !bucket) ? (
            <FranchisePublishReleaseForm locale={locale} workspace={workspace} commandIdentity={commandIdentity} organizationId={organizationId} />
          ) : null}
          <p className="client-access-note">{c.clientsNote}</p>
        </article>
        <FranchiseMandateRail locale={locale} name={workspace.mandate.libraryName} />
      </section>
    </main>
  );
}
