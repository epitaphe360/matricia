import Link from "next/link";
import { Bell, Search } from "lucide-react";
import type { ReactNode } from "react";
import { providerCopy } from "@/modules/provider/data/spaces/copy";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { buildProviderNav, type ProviderNavKey } from "@/modules/provider/ui/provider-nav";

export type { ProviderNavKey };

export function ProviderAppShell({
  locale,
  selectedQuery,
  selectedOrganizationId,
  userEmail,
  active,
  title,
  lead,
  kicker,
  actions,
  children,
}: {
  locale: Locale;
  selectedQuery: string;
  selectedOrganizationId: string | null;
  userEmail: string | null;
  active: ProviderNavKey;
  title?: string;
  lead?: string;
  kicker?: string;
  actions?: ReactNode;
  children: ReactNode;
}): ReactNode {
  const c = providerCopy(locale);
  const nav = buildProviderNav(locale, selectedQuery);

  return (
    <div dir={locale === "ar" ? "rtl" : "ltr"} className="client-workspace">
      <aside className="client-side" aria-label={c.space}>
        <Link href={`/${locale}/tableau-de-bord${selectedQuery}`} className="client-brand">
          <span className="client-brand-mark" aria-hidden>
            <svg viewBox="0 0 32 32" className="size-5" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M5 28V16a11 11 0 0 1 22 0v12" />
              <path d="M12 28V18a4 4 0 0 1 8 0v10" />
            </svg>
          </span>
          <span>
            <strong>Matricia</strong>
            <small>{c.space}</small>
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
        <p className="client-side-foot"><span aria-hidden>◆</span>{c.brandFooter}</p>
      </aside>
      <div className="client-frame">
        <div className="client-scene" aria-hidden>
          <div className="client-scene-arch" />
          <div className="client-scene-palms" />
          <div className="client-scene-pattern" />
        </div>
        <div className="client-topbar">
          <form className="client-top-search client-shell-search" method="get" action={`/${locale}/tableau-de-bord`} role="search" aria-label={c.searchConsult}>
            {selectedOrganizationId ? <input type="hidden" name="organizationId" value={selectedOrganizationId} /> : null}
            <Search aria-hidden className="size-4" />
            <label className="sr-only" htmlFor="provider-shell-search">{c.searchConsult}</label>
            <input id="provider-shell-search" name="q" placeholder={c.searchGlobal} />
          </form>
          <Link href={`/${locale}/notifications${selectedQuery}`} className="client-icon-btn" aria-label={locale === "ar" ? "الإشعارات" : "Notifications"}><Bell className="size-4" /></Link>
          <span className="client-space-chip">{c.space}</span>
          <span className="client-account" aria-label={c.space}><span className="client-chip">{userEmail?.slice(0, 1).toUpperCase() ?? "P"}</span></span>
        </div>
        {title ? (
          <header className="client-mast">
            <div>
              <p className="client-space-label">{c.space}</p>
              <h1>{title}</h1>
              {lead ? <p>{lead}</p> : null}
            </div>
            <div className="client-offer-actions">
              {actions}
              {kicker ? <small className="client-hello-kicker">{kicker}</small> : null}
            </div>
          </header>
        ) : null}
        {children}
      </div>
    </div>
  );
}

export function ProviderActions({ href, label }: { href: string; label: string }) {
  return <Link href={href} className="client-cta">{label}</Link>;
}
