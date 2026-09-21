import Link from "next/link";
import { Archive, ArrowRight, ChevronRight, Download, Eye, FileText, FolderKanban, MoreHorizontal, Pencil, Plus, Power, Search, Shield, Users } from "lucide-react";
import type { ReactNode } from "react";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import { adminDirectoryGroups, inferOrgType } from "@/modules/admin/data/spaces/directory";
import { organizationJourney, type AdminOrgRow, type AdminTreatItem } from "@/modules/admin/data/spaces/view-model";
import type { AdminOrganizationFiche } from "@/modules/admin/data/supervision/types";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

function Cta({ href, children }: { href: string; children: ReactNode }) {
  return <Link href={href} className="client-ghost-link">{children}<ArrowRight className="size-4 rtl:rotate-180" aria-hidden /></Link>;
}

export function AdminDirectoryBoard({ locale, query }: { locale: Locale; query: string }) {
  const c = adminCopy(locale);
  const groups = adminDirectoryGroups(locale, query);
  const actions = [
    { href: `/${locale}/administration/entreprises/nouvelle${query}`, label: c.create, tone: "violet" as const, icon: Plus },
    { href: `/${locale}/administration/entreprises${query}`, label: c.edit, tone: "peach" as const, icon: Pencil },
    { href: `/${locale}/administration/operations${query}`, label: c.archiveRestore, tone: "mint" as const, icon: Archive },
    { href: `/${locale}/administration/entreprises/export${query}`, label: c.export, tone: "white" as const, icon: Download },
  ];
  return (
    <main className="client-page">
      <section className="admin-home-toolbar">
        <div className="admin-dir-actions">
          {actions.map((item) => {
            const Icon = item.icon;
            return (
              <Link key={item.label} href={item.href} className="admin-dir-action" data-tone={item.tone}>
                <Icon className="size-4" aria-hidden />
                {item.label}
                <ChevronRight className="size-4 rtl:rotate-180" aria-hidden />
              </Link>
            );
          })}
        </div>
        <article className="admin-sensitive">
          <h2><Shield className="size-4" aria-hidden /> {c.sensitive}</h2>
          <ol>
            <li>{c.s1}</li>
            <li>{c.s2}</li>
            <li>{c.s3}</li>
            <li>{c.s4}</li>
            <li>{c.s5}</li>
          </ol>
        </article>
      </section>
      <section className="admin-dir-grid">
        {groups.map((group) => (
          <article key={group.id} className="admin-dir-card" data-tone={group.tone}>
            <header>{group.title}</header>
            <ul>
              {group.links.map((link) => (
                <li key={`${group.id}-${link.label}`}>
                  <Link href={link.href}>{link.label}<ChevronRight className="size-4 rtl:rotate-180" aria-hidden /></Link>
                </li>
              ))}
            </ul>
          </article>
        ))}
      </section>
      <p className="admin-foot-note">{c.foot}</p>
    </main>
  );
}

export function OrganizationsBoard({
  locale,
  query,
  rows,
  treat,
  search,
  archives,
}: {
  locale: Locale;
  query: string;
  rows: AdminOrgRow[];
  treat: AdminTreatItem[];
  search?: string;
  archives?: boolean;
}) {
  const c = adminCopy(locale);
  const filtered = rows.filter((row) => {
    if (!search) return true;
    const haystack = `${row.name} ${row.legalName} ${row.type} ${row.status}`.toLowerCase();
    return haystack.includes(search.toLowerCase());
  });
  return (
    <main className="client-page">
      <section className="admin-org-layout">
        <article className="client-card">
          <form className="admin-filters" method="get">
            <label>{c.type}<select name="type" defaultValue="all"><option value="all">{c.all}</option></select></label>
            <label>{c.state}<select name="status" defaultValue="all"><option value="all">{c.all}</option></select></label>
            <label>{c.compliance}<select name="compliance" defaultValue="all"><option value="all">{c.all}</option></select></label>
            <label>{c.plan}<select name="plan" defaultValue="all"><option value="all">{c.all}</option></select></label>
            <label className="admin-check"><input type="checkbox" name="archives" value="1" defaultChecked={archives} />{c.includeArchived}</label>
            <span className="admin-filter-link"><Link href={`/${locale}/administration/entreprises${query}${query ? "&" : "?"}archives=1`}>{c.seeArchives}</Link></span>
          </form>
          <form className="admin-table-tools" method="get" action={`/${locale}/administration/entreprises`}>
            <div>
              <h2>{c.allOrgs}</h2>
              <p>{c.allOrgsLead}</p>
            </div>
            <label className="client-top-search">
              <Search className="size-4" aria-hidden />
              <span className="sr-only">{c.searchList}</span>
              <input name="q" defaultValue={search} placeholder={c.searchList} />
            </label>
          </form>
          {filtered.length === 0 ? null : (
            <div className="client-table-wrap">
              <table className="client-space-table">
                <thead>
                  <tr>
                    <th>{c.orgs}</th>
                    <th>{c.type}</th>
                    <th>{c.state}</th>
                    <th>{c.compliance}</th>
                    <th>{c.plan}</th>
                    <th>{c.lastAction}</th>
                    <th>{c.actions}</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((row) => (
                    <tr key={row.id}>
                      <td>
                        <span className="client-doc-cell">
                          <span className="client-avatar" data-tone={row.statusTone}>{row.name.slice(0, 1)}</span>
                          {row.name}
                        </span>
                      </td>
                      <td>{row.type}</td>
                      <td><span className="client-status-chip" data-tone={row.statusTone}>{row.status}</span></td>
                      <td><span className="client-status-chip" data-tone={row.complianceTone}>{row.compliance}</span></td>
                      <td><span className="client-status-chip" data-tone="violet">{row.plan}</span></td>
                      <td>{row.lastAction}</td>
                      <td>
                        <details className="admin-row-menu">
                          <summary aria-label={c.actions}><MoreHorizontal className="size-4" /></summary>
                          <div>
                            <Link href={`/${locale}/administration/entreprises/${row.id}${query}`}><Eye className="size-3.5" aria-hidden />{c.consult}</Link>
                            <Link href={`/${locale}/administration/entreprises/${row.id}/modifier${query}`}><Pencil className="size-3.5" aria-hidden />{c.edit}</Link>
                            <Link href={`/${locale}/administration/entreprises/${row.id}/archiver${query ? `${query}&mode=disable` : "?mode=disable"}`}><Power className="size-3.5" aria-hidden />{c.disable}</Link>
                            <Link href={`/${locale}/administration/entreprises/${row.id}/archiver${query}`} data-tone="peach"><Archive className="size-3.5" aria-hidden />{c.archive}</Link>
                          </div>
                        </details>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {filtered.length === 0 ? (
            <div className="admin-empty-card">
              <FolderKanban className="size-6" aria-hidden />
              <h3>{c.emptyOrgs}</h3>
              <p>{c.emptyOrgsLead}</p>
              <div className="admin-empty-actions">
                <Link href={`/${locale}/administration/entreprises`} className="client-ghost-link">{c.reset}</Link>
                <Link href={`/${locale}/administration/entreprises/nouvelle${query}`} className="admin-primary-cta">{c.createOrg}</Link>
              </div>
            </div>
          ) : null}
          {archives ? (
            <p className="client-access-note">{c.archivesNote} {c.noArchives}</p>
          ) : null}
        </article>
        <aside className="client-card admin-treat-rail">
          <h2>{c.toTreat}</h2>
          <p>{c.toTreatLead}</p>
          <ul className="client-feed">
            {treat.length === 0 ? <li><span>{c.emptyOrgsLead}</span></li> : treat.map((item) => (
              <li key={item.id}>
                <span className="client-feed-icon" data-tone={item.tone}><FileText className="size-4" aria-hidden /></span>
                <span><strong>{item.title}</strong><small>{item.detail}</small></span>
                <Cta href={item.href}>{c.open}</Cta>
              </li>
            ))}
          </ul>
          <Cta href={`/${locale}/administration/parcours${query}`}>{c.seeQueue}</Cta>
          <p className="client-access-note">{c.controlNote}</p>
        </aside>
      </section>
    </main>
  );
}

export function OrganizationFicheBoard({
  locale,
  query,
  fiche,
}: {
  locale: Locale;
  query: string;
  fiche: AdminOrganizationFiche;
}) {
  const c = adminCopy(locale);
  const org = fiche.organization;
  const base = `/${locale}/administration/entreprises/${org.id}`;
  const journey = organizationJourney(fiche, locale);
  const required = [
    { href: `${base}/modifier${query}`, title: c.completeInfo, detail: c.completeInfoLead, tone: "peach" as const },
    { href: `/${locale}/administration/conformite-clients${query}`, title: c.finishCompliance, detail: c.finishComplianceLead, tone: "peach" as const },
    { href: `/${locale}/administration/parcours${query}`, title: c.completeFolder, detail: c.completeFolderLead, tone: "sky" as const },
    { href: `${base}${query}#membres`, title: c.assignRoles, detail: c.assignRolesLead, tone: "peach" as const },
  ];
  const history = fiche.timeline.slice(0, 4);
  return (
    <main className="client-page">
      <nav className="client-tabs" aria-label={c.overview}>
        <a href={`${base}${query}`} aria-current="page">{c.overview}</a>
        <a href={`${base}${query}#membres`}>{c.members}</a>
        <a href={`/${locale}/administration/conformite-clients${query}`}>{c.compliance}</a>
        <a href={`/${locale}/administration/parcours${query}`}>{c.dossiers}</a>
        <a href={`${base}${query}#documents`}>{c.documents}</a>
        <a href={`${base}${query}#boxes`}>{c.boxes}</a>
        <a href={`/${locale}/administration/finance${query}`}>{c.navFinance}</a>
        <a href={`/${locale}/administration/operations${query}`}>{c.audit}</a>
      </nav>
      <section className="admin-fiche-grid">
        <article className="client-card">
          <header><h2>{c.info}</h2></header>
          <dl className="admin-dl">
            <div><dt>{c.legal}</dt><dd>{org.legal_name}</dd></div>
            <div><dt>{c.type}</dt><dd>{inferOrgType(`${org.display_name} ${org.legal_name}`, locale)}</dd></div>
            <div><dt>{c.activity}</dt><dd>{org.display_name}</dd></div>
            <div><dt>{c.contact}</dt><dd>{org.country_code}</dd></div>
            <div><dt>{c.address}</dt><dd>{org.country_code}</dd></div>
            <div><dt>{c.ids}</dt><dd dir="ltr">{org.id.slice(0, 8)}…</dd></div>
          </dl>
        </article>
        <article className="client-card">
          <header><h2>{c.journey}</h2></header>
          <ol className="admin-journey">
            {journey.map((step) => (
              <li key={step.id} data-state={step.state}>
                <i aria-hidden />
                <span><strong>{step.label}</strong><small>{step.detail}</small></span>
              </li>
            ))}
          </ol>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.required}</h2><Cta href={`/${locale}/administration/parcours${query}`}>{c.seeAll}</Cta></header>
          <ul className="admin-req-list">
            {required.map((item) => (
              <li key={item.title}>
                <span><strong>{item.title}</strong><small>{item.detail}</small></span>
                <Link href={item.href} className="admin-soft-cta">{c.open}</Link>
              </li>
            ))}
          </ul>
        </article>
      </section>
      <section className="admin-fiche-lower">
        <article className="client-card" id="membres">
          <header className="client-priority-head"><h2>{c.members}</h2><Cta href={`${base}${query}#membres`}>{c.seeAll}</Cta></header>
          <ul className="client-feed">
            <li><Users className="size-4" aria-hidden /><span><strong>{c.membersCount}</strong><small dir="ltr">{fiche.memberships.length}</small></span></li>
            <li><span><strong>{c.roles}</strong><small>{fiche.memberships[0]?.roles.join(", ") || "—"}</small></span></li>
            <li><span><strong>{c.access}</strong><small>{fiche.memberships.filter((item) => item.status === "ACTIVE").length}</small></span></li>
            <li><span><strong>{c.invites}</strong><small>{fiche.memberships.filter((item) => item.status !== "ACTIVE").length}</small></span></li>
          </ul>
          <Link href={`${base}${query}#membres`} className="admin-soft-cta">{c.manageMembers}</Link>
        </article>
        <article className="client-card" id="boxes">
          <header className="client-priority-head"><h2>{c.boxes}</h2></header>
          <ul className="client-feed">
            <li><span><strong>{c.plan}</strong><small>{fiche.subscriptions[0]?.status ?? c.unknownPlan}</small></span></li>
            <li><span><strong>{c.boxesActive}</strong><small>{fiche.subscriptions.length}</small></span></li>
            <li><span><strong>{c.credits}</strong><small>{c.unknownPlan}</small></span></li>
            <li><span><strong>{c.nextBill}</strong><small dir="ltr">{fiche.subscriptions[0]?.current_period_end ?? "—"}</small></span></li>
          </ul>
          <Link href={`/${locale}/administration/finance${query}`} className="admin-dir-action" data-tone="mint">{c.seeFinance}</Link>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.dossiers}</h2><Cta href={`/${locale}/administration/parcours${query}`}>{c.seeAll}</Cta></header>
          <ul className="client-feed">
            <li><span><strong>{c.inProgress}</strong><small>{fiche.requests.length}</small></span></li>
            <li><span><strong>{c.waiting}</strong><small>{fiche.disputes.length}</small></span></li>
            <li><span><strong>{c.toComplete}</strong><small>{fiche.diagnostics.length}</small></span></li>
            <li><span><strong>{c.recently}</strong><small>{fiche.missions.length}</small></span></li>
          </ul>
          <Link href={`/${locale}/administration/conformite-clients${query}`} className="admin-dir-action" data-tone="peach">{c.openCompliance}</Link>
        </article>
        <article className="client-card">
          <header className="client-priority-head"><h2>{c.lastChange}</h2><Cta href={`/${locale}/administration/operations${query}`}>{c.seeAll}</Cta></header>
          <ul className="client-feed">
            {history.length === 0 ? (
              <li><span><strong>—</strong><small>{c.lastChangeLead}</small></span></li>
            ) : history.map((item) => (
              <li key={item.ref}><span className="client-history-dot" data-tone="violet" /><span><strong>{item.label}</strong><small dir="ltr">{item.at?.slice(0, 16) ?? "—"}</small></span></li>
            ))}
          </ul>
          <Link href={`/${locale}/administration/operations${query}`} className="admin-dir-action" data-tone="violet">{c.seeAudit}</Link>
        </article>
      </section>
    </main>
  );
}
