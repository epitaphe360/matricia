import Link from "next/link";
import { Lock, Pencil } from "lucide-react";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { catalogStatusLabel, type FranchiseCatalogRow, type FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { KindChip, LanguageMarks, MandateBanner, nextAction } from "./library-boards";
import { FranchisePublishReleaseForm } from "./catalog-commands";

export const FRANCHISE_VALIDATION_BUCKETS: Record<string, string[] | null> = {
  brouillons: ["DRAFT"],
  "en-cours": ["IN_REVIEW", "FRANCHISE_REVIEW", "CENTRAL_REVIEW", "LOCAL_TEST"],
  corrections: ["REJECTED", "CHANGES_REQUESTED"],
  approuves: ["APPROVED"],
  publications: ["PUBLISHED"],
  historique: null,
};

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

function reviewStatus(status: string, locale: Locale) {
  const c = libraryCopy(locale);
  if (status === "DRAFT") return c.notSubmitted;
  return catalogStatusLabel(status, locale);
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
  const activeBucket = bucket && bucket in FRANCHISE_VALIDATION_BUCKETS ? bucket : "brouillons";
  const rows = filterRows(all, activeBucket);
  const selected = rows[0] ?? null;
  const bucketKeys = Object.keys(FRANCHISE_VALIDATION_BUCKETS);
  return (
    <main className="client-page">
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <nav className="franchise-pill-tabs" aria-label={c.validationsTitle}>
        {bucketKeys.map((key) => (
          <Link
            key={key}
            href={`/${locale}/franchise/validations/${key}${query}`}
            className="franchise-pill-tab"
            data-active={activeBucket === key ? "true" : undefined}
          >
            <span>{bucketLabel(key, locale)}</span>
            <em dir="ltr">{key === "historique" ? all.length : filterRows(all, key).length}</em>
          </Link>
        ))}
      </nav>
      <section className="franchise-validation-grid">
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{c.queueItems} <small dir="ltr">({rows.length})</small></h2>
          </header>
          <form className="franchise-filters" action={`/${locale}/franchise/validations/${activeBucket}`} method="get">
            <label>
              <span className="sr-only">{c.kind}</span>
              <select name="type" defaultValue="all"><option value="all">{c.queueAllTypes}</option></select>
            </label>
            <label>
              <span className="sr-only">{c.category}</span>
              <select name="category" defaultValue="all"><option value="all">{c.categoriesOfLibrary}</option></select>
            </label>
            <label className="franchise-search">
              <span className="sr-only">{c.search}</span>
              <input name="q" placeholder={c.search} />
            </label>
          </form>
          {rows.length === 0 ? <p>{c.emptyQueue}</p> : (
            <div className="client-table-wrap client-compare">
              <table className="client-space-table">
                <thead>
                  <tr>
                    <th>{c.kind}</th>
                    <th>{c.element}</th>
                    <th>{c.version}</th>
                    <th>{c.languages}</th>
                    <th>{c.modifiedOn}</th>
                    <th>{c.reviewStatus}</th>
                    <th>{c.lastComment}</th>
                    <th>{c.next}</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((item, index) => (
                    <tr key={`${item.kind}-${item.id}`} data-selected={index === 0 ? "true" : undefined}>
                      <td><KindChip kind={item.kind} locale={locale} /></td>
                      <td>
                        <strong>{item.title}</strong>
                        <small>{item.subcategory ?? item.category ?? workspace.mandate.libraryName}</small>
                      </td>
                      <td><span className="franchise-version-chip" dir="ltr">{item.versionLabel ?? "v1.0"}</span></td>
                      <td><LanguageMarks item={item} /></td>
                      <td>—</td>
                      <td><em className="client-status-chip" data-tone={item.status === "DRAFT" ? "sky" : "peach"}>{reviewStatus(item.status, locale)}</em></td>
                      <td>—</td>
                      <td>
                        <Link href={item.href} className="franchise-tool franchise-tool-primary">
                          {item.status === "DRAFT" ? c.submitRow : nextAction(item.status, locale)}
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {commandIdentity && (activeBucket === "approuves" || activeBucket === "publications") ? (
            <FranchisePublishReleaseForm locale={locale} workspace={workspace} commandIdentity={commandIdentity} organizationId={organizationId} />
          ) : null}
          <p className="client-access-note">{c.clientsNote}</p>
        </article>
        <aside className="client-card franchise-review-panel">
          <header>
            <h2>{c.reviewPanel}</h2>
            {selected ? (
              <p>
                <KindChip kind={selected.kind} locale={locale} />
                <strong>{selected.title}</strong>
                <small>{selected.versionLabel ?? "v1.0"} · {selected.subcategory ?? selected.category ?? workspace.mandate.libraryName}</small>
              </p>
            ) : <p>{c.emptyQueue}</p>}
          </header>
          <p className="franchise-mandate-banner" role="note">
            <Lock className="size-3.5" aria-hidden />
            <span>{c.scope} {workspace.mandate.libraryName}</span>
          </p>
          <nav className="franchise-inspector-tabs" aria-label={c.reviewPanel}>
            <span data-active="true">{c.reviewTimeline}</span>
            <span>{c.reviewDetails}</span>
          </nav>
          <ol className="franchise-review-steps">
            {c.validationSteps.map(([title, text], index) => (
              <li key={title} data-done={index === 0 ? "true" : undefined}>
                <em aria-hidden>{index === 0 ? "✓" : index + 1}</em>
                <span>
                  <strong>{title}</strong>
                  <small>{text}</small>
                </span>
              </li>
            ))}
          </ol>
          <div className="franchise-comment-box">
            <strong>{c.lastComment}</strong>
            <p>{c.noComment}</p>
          </div>
          <div className="franchise-toolbar">
            {selected ? <Link href={selected.href} className="franchise-tool"><Pencil className="size-4" aria-hidden /> {c.fixDraft}</Link> : null}
            <p className="client-access-note">{c.seeApproved}</p>
          </div>
        </aside>
      </section>
    </main>
  );
}
