import Link from "next/link";
import { ArrowRight, Beaker, BookOpen, ClipboardList, FileText, Globe, Lock, MessageSquare, Scale, Send,  Users } from "lucide-react";
import type { ReactNode } from "react";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { catalogStatusLabel, catalogStatusTone, type FranchiseCatalogRow, type FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { FranchiseMandatePerimeter, FranchiseRowMenu, validationChipLabel, validationChipTone, workflowChipLabel } from "./library-chrome";
import { FranchiseCategoryCreateForm, FranchiseHierarchySubmitForm, FranchiseSubcategoryCreateForm } from "./catalog-commands";

const pipelineIcons = [ClipboardList, FileText, Scale, Beaker, Send, Globe, Users] as const;
const pipelineTones = ["violet", "peach", "mint", "sky", "peach", "mint", "violet"] as const;
const kpiIcons = [FileText, Send, MessageSquare, BookOpen] as const;
const kpiTones = ["violet", "peach", "mint", "sky"] as const;

export function nextAction(status: string, locale: Locale) {
  const c = libraryCopy(locale);
  if (status === "DRAFT") return c.completeDraft;
  if (status === "REJECTED" || status === "CHANGES_REQUESTED") return c.seeComments;
  if (["IN_REVIEW", "FRANCHISE_REVIEW", "CENTRAL_REVIEW"].includes(status)) return c.waitReturn;
  if (status === "PUBLISHED" || status === "APPROVED") return c.simulate;
  return c.submit;
}

export function kindLabel(kind: FranchiseCatalogRow["kind"], locale: Locale) {
  const c = libraryCopy(locale);
  if (kind === "SERVICE") return c.serviceKind;
  if (kind === "QUESTIONNAIRE") return c.questionnaireKind;
  return c.ruleKind;
}

export function MandateBanner({ locale, name }: { locale: Locale; name: string }) {
  const c = libraryCopy(locale);
  return (
    <p className="franchise-mandate-banner" role="status">
      <span className="franchise-pipe-icon" data-tone="sky" aria-hidden>
        <Lock className="size-3.5" />
      </span>
      <span>
        <strong>{c.scope}</strong>
        <small>{c.scopeHelp} {name}</small>
      </span>
    </p>
  );
}

export function StatusChip({ status, locale }: { status: string; locale: Locale }) {
  return <em className="client-status-chip" data-tone={catalogStatusTone(status)}>{catalogStatusLabel(status, locale)}</em>;
}

export function LanguageMarks({ item }: { item: FranchiseCatalogRow }) {
  const hasFr = Boolean(item.nameFr) || item.kind === "RULE" || item.status === "PUBLISHED";
  const hasAr = Boolean(item.nameAr) || item.kind === "RULE";
  return (
    <span className="franchise-langs">
      {hasFr ? <span className="franchise-lang">FR</span> : null}
      {hasAr ? <span className="franchise-lang" data-tone="mint">AR</span> : null}
    </span>
  );
}

export function KindChip({ kind, locale }: { kind: FranchiseCatalogRow["kind"]; locale: Locale }) {
  return <em className="franchise-kind-chip" data-kind={kind}>{kindLabel(kind, locale)}</em>;
}

function KindIcon({ kind }: { kind: FranchiseCatalogRow["kind"] }) {
  if (kind === "QUESTIONNAIRE") return <FileText className="size-4" aria-hidden />;
  if (kind === "RULE") return <Scale className="size-4" aria-hidden />;
  return <ClipboardList className="size-4" aria-hidden />;
}

export function FranchiseLibraryHomeBoard({ locale, query, workspace }: { locale: Locale; query: string; workspace: FranchiseLibraryWorkspace }) {
  const c = libraryCopy(locale);
  const queue = [...workspace.questionnaires, ...workspace.services, ...workspace.rules]
    .filter((item) => item.status !== "ARCHIVED" && item.status !== "RETIRED")
    .slice(0, 8);
  const treatItems = [
    ...queue.slice(0, 3).map((item, index) => ({ href: item.href, title: item.title, tone: (["peach", "sky", "violet"] as const)[index] ?? "peach" })),
    { href: `/${locale}/franchise/questionnaires${query}`, title: c.addAr, tone: "violet" as const },
    { href: `/${locale}/franchise/validations${query}`, title: c.submit, tone: "mint" as const },
    { href: `/${locale}/franchise/regles${query}#simulation`, title: c.simulate, tone: "sky" as const },
  ].slice(0, 5);
  const activity = [...workspace.questionnaires, ...workspace.services, ...workspace.rules, ...workspace.releases.map((item) => ({ id: item.id, title: item.key, status: item.status, href: `/${locale}/franchise/validations${query}`, kind: "QUESTIONNAIRE" as const }))]
    .slice(0, 5);
  const kpis = [
    { label: c.drafts, help: c.draftsHelp, value: workspace.counts.drafts, href: `/${locale}/franchise/validations/brouillons${query}` },
    { label: c.inReview, help: c.inReviewHelp, value: workspace.counts.inReview, href: `/${locale}/franchise/validations/en-cours${query}` },
    { label: c.returns, help: c.returnsHelp, value: workspace.counts.returns, href: `/${locale}/franchise/validations/corrections${query}` },
    { label: c.published, help: c.publishedHelp, value: workspace.counts.published, href: `/${locale}/franchise/validations/publications${query}` },
  ];
  return (
    <main className="client-page">
      <section className="franchise-treat">
        {kpis.map((item, index) => {
          const Icon = kpiIcons[index] ?? FileText;
          return (
            <Link key={item.label} href={item.href} className="franchise-kpi-tile" data-tone={kpiTones[index]}>
              <span className="franchise-kpi-icon"><Icon className="size-4" aria-hidden /></span>
              <span>
                <strong>{item.label}</strong>
                <small><bdi dir="ltr">{item.value}</bdi> · {item.help}</small>
              </span>
              <ArrowRight className="size-4 rtl:rotate-180" aria-hidden />
            </Link>
          );
        })}
      </section>
      <article className="client-card">
        <header><h2>{c.journey}</h2></header>
        <ol className="franchise-pipeline">
          {c.steps.map(([title, text], index) => {
            const Icon = pipelineIcons[index] ?? ClipboardList;
            return (
              <li key={title}>
                <span className="franchise-pipe-row">
                  <span className="franchise-pipe-icon" data-tone={pipelineTones[index]}><Icon className="size-4" /></span>
                  {index < c.steps.length - 1 ? <span className="franchise-pipe-arrow" aria-hidden /> : null}
                </span>
                <strong>{index + 1}. {title}</strong>
                <small>{text}</small>
              </li>
            );
          })}
        </ol>
      </article>
      <section className="franchise-home-grid">
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.queue}</h2><Link href={`/${locale}/franchise/validations${query}`} className="client-soft-link">{c.seeAll}</Link></header>
          {queue.length === 0 ? <p>{c.emptyQueue}</p> : (
            <div className="client-table-wrap client-compare">
              <table className="client-space-table">
                <thead>
                  <tr>
                    <th>{c.element}</th>
                    <th>{c.kind}</th>
                    <th>{c.linked}</th>
                    <th>{c.version}</th>
                    <th>{c.languages}</th>
                    <th>{c.validation}</th>
                    <th>{c.state}</th>
                    <th>{c.next}</th>
                    <th><span className="sr-only">{c.rowActions}</span></th>
                  </tr>
                </thead>
                <tbody>
                  {queue.map((item) => (
                    <tr key={item.id}>
                      <td>
                        <span className="franchise-row-title">
                          <span className="franchise-kpi-icon" data-tone="violet"><KindIcon kind={item.kind} /></span>
                          <strong>{item.title}</strong>
                        </span>
                      </td>
                      <td><KindChip kind={item.kind} locale={locale} /></td>
                      <td>{item.subcategory ?? item.category ?? "—"}</td>
                      <td>{item.versionLabel ?? "—"}</td>
                      <td><LanguageMarks item={item} /></td>
                      <td><em className="client-status-chip" data-tone={validationChipTone(item.status)}>{validationChipLabel(item.status, locale)}</em></td>
                      <td><em className="client-status-chip" data-tone={catalogStatusTone(item.status)}>{workflowChipLabel(item.status, locale)}</em></td>
                      <td><Link href={item.href}>{nextAction(item.status, locale)}</Link></td>
                      <td><FranchiseRowMenu href={item.href} label={item.title} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          <header className="client-priority-head franchise-section-head"><h2>{c.quick}</h2></header>
          <div className="franchise-toolbar">
            <Link href={`/${locale}/franchise/services/nouveau${query}`} className="franchise-tool franchise-tool-primary"><ClipboardList className="size-4" aria-hidden /> {c.createService}</Link>
            <Link href={`/${locale}/franchise/questionnaires/nouveau${query}`} className="franchise-tool franchise-tool-peach"><FileText className="size-4" aria-hidden /> {c.createQuestion}</Link>
            <Link href={`/${locale}/franchise/regles/nouvelle${query}`} className="franchise-tool franchise-tool-mint"><Scale className="size-4" aria-hidden /> {c.createRule}</Link>
            <Link href={`/${locale}/franchise/regles${query}#simulation`} className="franchise-tool"><Beaker className="size-4" aria-hidden /> {c.simulate}</Link>
          </div>
          <p className="client-access-note">{c.clientsNote}</p>
        </article>
        <aside className="franchise-home-rail">
          <article className="client-card">
            <header className="client-priority-head"><h2>{c.treatNow}</h2><Link href={`/${locale}/franchise/validations${query}`} className="client-soft-link">{c.seeAll}</Link></header>
            <ul className="franchise-dot-list">
              {treatItems.map((item) => (
                <li key={`${item.href}-${item.title}`}>
                  <span className="franchise-dot" data-tone={item.tone} />
                  <strong>{item.title}</strong>
                  <Link href={item.href} className="client-soft-link" aria-label={item.title}><ArrowRight className="size-4 rtl:rotate-180" /></Link>
                </li>
              ))}
            </ul>
          </article>
          <FranchiseMandatePerimeter locale={locale} name={workspace.mandate.libraryName} />
          <article className="client-card franchise-reminders">
            <header><h2>{c.reminders}</h2></header>
            <ul className="franchise-dot-list">
              {c.reminderItems.map((item) => (
                <li key={item}><span className="franchise-dot" data-tone="peach" /><span>{item}</span></li>
              ))}
            </ul>
          </article>
          <article className="client-card" id="activite">
            <header className="client-priority-head"><h2>{c.activity}</h2><Link href={`/${locale}/franchise/validations/historique${query}`} className="client-soft-link">{c.seeAll}</Link></header>
            {activity.length === 0 ? <p>{c.noActivity}</p> : (
              <ol className="franchise-activity">
                {activity.map((item) => (
                  <li key={item.id}>
                    <span className="franchise-dot" data-tone={catalogStatusTone(item.status)} />
                    <span><strong>{item.title}</strong><small>{catalogStatusLabel(item.status, locale)}</small></span>
                  </li>
                ))}
              </ol>
            )}
          </article>
        </aside>
      </section>
    </main>
  );
}

export function FranchiseCatalogListBoard({
  locale,
  title,
  empty,
  rows,
  actions,
  createHref,
  createLabel,
}: {
  locale: Locale;
  title: string;
  empty: string;
  rows: FranchiseCatalogRow[];
  actions?: ReactNode;
  createHref: string;
  createLabel: string;
}) {
  const c = libraryCopy(locale);
  return (
    <main className="client-page">
      <div className="franchise-toolbar">
        <Link href={createHref} className="franchise-tool franchise-tool-primary">{createLabel}</Link>
        {actions}
      </div>
      <article className="client-card">
        <header><h2>{title}</h2></header>
        {rows.length === 0 ? <p>{empty}</p> : (
          <ul className="client-feed">
            {rows.map((item) => (
              <li key={item.id} id={item.id}>
                <span className="client-feed-icon" data-tone="violet"><KindIcon kind={item.kind} /></span>
                <span>
                  <strong>{item.title}</strong>
                  <small><bdi dir="ltr">{item.code}</bdi>{item.versionLabel ? ` · ${item.versionLabel}` : ""} · {catalogStatusLabel(item.status, locale)}</small>
                </span>
                <Link href={item.href} className="client-soft-link">{nextAction(item.status, locale)}</Link>
              </li>
            ))}
          </ul>
        )}
        <p className="client-access-note">{c.clientsNote}</p>
      </article>
    </main>
  );
}

export function FranchiseLibraryStructureBoard({
  locale,
  query,
  workspace,
  view,
  commandIdentity,
  organizationId = null,
}: {
  locale: Locale;
  query: string;
  workspace: FranchiseLibraryWorkspace;
  view: "categories" | "version" | "historique";
  commandIdentity: { idempotencyKey: string; correlationId: string };
  organizationId?: string | null;
}) {
  const c = libraryCopy(locale);
  const tabs = [
    { id: "categories", href: `/${locale}/franchise/bibliotheque/categories${query}`, label: c.category },
    { id: "version", href: `/${locale}/franchise/bibliotheque/version${query}`, label: c.version },
    { id: "historique", href: `/${locale}/franchise/bibliotheque/historique${query}`, label: c.activity },
  ] as const;
  return (
    <main className="client-page" data-franchise-nested={view}>
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <nav className="franchise-inspector-tabs" aria-label={c.libraryTitle}>
        {tabs.map((tab) => (
          <Link key={tab.id} href={tab.href} data-active={view === tab.id ? "true" : undefined}>{tab.label}</Link>
        ))}
      </nav>
      <section className="franchise-workbench">
        {view === "categories" ? (
          <article className="client-card">
            <header><h2>{c.category}</h2></header>
            {workspace.categories.length === 0 ? <p className="franchise-empty-panel">{c.emptyCategories}</p> : (
              <ul className="client-feed">
                {workspace.categories.map((category) => (
                  <li key={category.id}>
                    <span><strong>{category.title}</strong><small>{category.children.map((child) => child.title).join(" · ") || c.subcategory}</small></span>
                    <em className="client-status-chip">{category.status ?? workspace.mandate.libraryStatus}</em>
                  </li>
                ))}
              </ul>
            )}
            <FranchiseCategoryCreateForm locale={locale} libraryId={workspace.mandate.libraryId} organizationId={organizationId} commandIdentity={commandIdentity} />
            <FranchiseSubcategoryCreateForm locale={locale} libraryId={workspace.mandate.libraryId} organizationId={organizationId} commandIdentity={commandIdentity} categories={workspace.categories} />
            {workspace.categories.flatMap((category) => [
              <FranchiseHierarchySubmitForm key={`cat-${category.id}`} locale={locale} libraryId={workspace.mandate.libraryId} organizationId={organizationId} commandIdentity={commandIdentity} objectType="CATEGORY" item={category} />,
              ...category.children.map((child) => (
                <FranchiseHierarchySubmitForm key={`sub-${child.id}`} locale={locale} libraryId={workspace.mandate.libraryId} organizationId={organizationId} commandIdentity={commandIdentity} objectType="SUBCATEGORY" item={child} />
              )),
            ])}
          </article>
        ) : null}
        {view === "version" ? (
          <article className="client-card">
            <header><h2>{c.version}</h2></header>
            <dl className="franchise-props">
              <div><small>{c.libraryTitle}</small><span>{workspace.mandate.libraryName}</span></div>
              <div><small>{c.version}</small><span dir="ltr">{workspace.mandate.libraryRowVersion}</span></div>
              <div><small>{c.state}</small><span>{workspace.mandate.libraryStatus}</span></div>
            </dl>
          </article>
        ) : null}
        {view === "historique" ? (
          <article className="client-card">
            <header><h2>{c.activity}</h2></header>
            {workspace.releases.length === 0 ? <p className="franchise-empty-panel">{c.noActivity}</p> : (
              <ol className="franchise-activity">
                {workspace.releases.map((item) => (
                  <li key={item.id}><span className="franchise-dot" data-tone="violet" /><span><strong>{item.key}</strong><small>{item.status}</small></span></li>
                ))}
              </ol>
            )}
          </article>
        ) : null}
        <FranchiseMandatePerimeter locale={locale} name={workspace.mandate.libraryName} />
      </section>
    </main>
  );
}

export function FranchiseQuestionsBoard({ locale, questions }: { locale: Locale; questions: FranchiseLibraryWorkspace["questions"] }) {
  const c = libraryCopy(locale);
  return (
    <article className="client-card">
      <header><h2>{c.createQuestion}</h2></header>
      {questions.length === 0 ? <p>{c.emptyQuestions}</p> : (
        <ul className="client-feed">
          {questions.map((item) => (
            <li key={item.id}>
              <span className="client-feed-icon" data-tone="mint"><Scale className="size-4" aria-hidden /></span>
              <span><strong>{item.label}</strong><small dir="ltr">{item.key} · {catalogStatusLabel(item.status, locale)}</small></span>
            </li>
          ))}
        </ul>
      )}
    </article>
  );
}
