import Link from "next/link";
import { Bell, Lock, Search } from "lucide-react";
import type { ReactNode } from "react";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import { franchiseCopy } from "@/modules/franchise/data/spaces/copy";
import { buildFranchiseNav, type FranchiseNavKey } from "@/modules/franchise/ui/franchise-nav";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import "@/modules/client/ui/client-experience.css";
import "./franchise-experience.css";

export type { FranchiseNavKey };

export function FranchiseAppShell({
  locale,
  selectedQuery,
  selectedOrganizationId,
  userEmail,
  active,
  title,
  lead,
  kicker,
  actions,
  mandateName,
  children,
}: {
  locale: Locale;
  selectedQuery: string;
  selectedOrganizationId: string | null;
  userEmail: string | null;
  active: FranchiseNavKey;
  title?: string;
  lead?: string;
  kicker?: string;
  actions?: ReactNode;
  mandateName?: string | null;
  children: ReactNode;
}): ReactNode {
  const c = franchiseCopy(locale);
  const n = libraryCopy(locale);
  const nav = buildFranchiseNav(locale, selectedQuery);
  const routeByActive: Record<FranchiseNavKey, string> = {
    home: "accueil",
    library: "bibliotheque",
    services: "services",
    questionnaires: "questionnaires",
    rules: "regles",
    validations: "validations",
    perimeter: "perimetre",
    network: "fournisseurs",
    requests: "demandes",
    quality: "qualite",
    performance: "performance",
    followups: "relances",
    documents: "documents",
    messages: "messages",
    governance: "gouvernance",
    finance: "finance",
  };

  return (
    <div dir={locale === "ar" ? "rtl" : "ltr"} className="client-workspace">
      <aside className="client-side" aria-label={c.space}>
        <Link href={`/${locale}/franchise/accueil${selectedQuery}`} className="client-brand">
          <span className="client-brand-mark" aria-hidden>
            <svg viewBox="0 0 32 32" className="size-5" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M5 28V16a11 11 0 0 1 22 0v12" />
              <path d="M12 28V18a4 4 0 0 1 8 0v10" />
            </svg>
          </span>
          <span>
            <strong>Matricia</strong>
            <small>{n.brandSpace}</small>
          </span>
        </Link>
        <nav className="client-side-nav">
          {nav.map((item) => {
            const Icon = item.icon;
            return (
              <Link key={item.key} href={item.href} data-active={item.key === active ? "true" : undefined}>
                <Icon aria-hidden className="size-4" />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <p className="client-side-foot"><span aria-hidden>◆</span>{n.sideFoot}</p>
      </aside>
      <div className="client-frame">
        <div className="client-scene" aria-hidden>
          <div className="client-scene-arch" />
          <div className="client-scene-palms" />
          <div className="client-scene-pattern" />
        </div>
        <div className="client-topbar">
          {mandateName ? (
            <>
              <span className="franchise-mandate-chip">
                <Lock className="size-3.5" aria-hidden />
                <span><small>{n.mandateChip}</small><strong> {mandateName}</strong></span>
              </span>
              <span className="franchise-scope-chip">{n.scope}</span>
            </>
          ) : null}
          <form className="client-top-search client-shell-search" method="get" action={`/${locale}/franchise/bibliotheque`} role="search" aria-label={n.search}>
            {selectedOrganizationId ? <input type="hidden" name="organizationId" value={selectedOrganizationId} /> : null}
            <Search aria-hidden className="size-4" />
            <label className="sr-only" htmlFor="franchise-shell-search">{n.search}</label>
            <input id="franchise-shell-search" name="q" placeholder={n.search} />
          </form>
          <Link href={`/${locale}/notifications${selectedQuery}`} className="client-icon-btn" aria-label={locale === "ar" ? "الإشعارات" : "Notifications"}><Bell className="size-4" /></Link>
          <nav className="client-lang-switch" aria-label={n.language}>
            <Link href={`/fr/franchise/${routeByActive[active]}${selectedQuery}`} aria-current={locale === "fr" ? "page" : undefined}>FR</Link>
            <Link href={`/ar/franchise/${routeByActive[active]}${selectedQuery}`} aria-current={locale === "ar" ? "page" : undefined}>AR</Link>
          </nav>
          <Link href={`/${locale}/securite/compte${selectedQuery}`} className="client-space-chip" aria-label={n.account}>{n.account}</Link>
          <span className="client-account" aria-label={n.account}><span className="client-chip">{userEmail?.slice(0, 1).toUpperCase() ?? "F"}</span></span>
        </div>
        {title ? (
          <header className="client-mast">
            <div>
              {kicker ? <p className="sr-only">{kicker}</p> : null}
              <h1>{title}</h1>
              {lead ? <p>{lead}</p> : null}
            </div>
            <div className="client-offer-actions">
              {actions}
            </div>
          </header>
        ) : null}
        {children}
      </div>
    </div>
  );
}

export function FranchiseActions({ href, label }: { href: string; label: string }) {
  return <Link href={href} className="client-cta">{label}</Link>;
}
