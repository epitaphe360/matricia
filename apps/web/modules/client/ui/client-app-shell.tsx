import Link from "next/link";
import { Bell, Building2, Search } from "lucide-react";
import type { ReactNode } from "react";
import { clientDashboardCopy } from "@/modules/client/data/home/copy";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { ClientNavKey } from "@/modules/client/ui/client-nav";
import { ClientWorkspaceNav } from "@/modules/client/ui/client-workspace-nav";
import "./client-experience.css";

export type { ClientNavKey };

export function ClientAppShell({
  locale,
  selectedQuery,
  selectedOrganizationId,
  userEmail,
  active,
  searchAction,
  searchQuery = "",
  title,
  lead,
  kicker,
  actions,
  messagesUnread,
  theme = "default",
  children,
}: {
  locale: Locale;
  selectedQuery: string;
  selectedOrganizationId: string | null;
  userEmail: string | null;
  active?: ClientNavKey;
  messagesUnread?: boolean;
  searchAction?: string;
  searchQuery?: string;
  title?: string;
  lead?: string;
  kicker?: string;
  actions?: ReactNode;
  theme?: "default" | "follow";
  children: ReactNode;
}): ReactNode {
  const c = clientDashboardCopy[locale];
  const space = spaceCopy(locale);
  const searchPath = searchAction ?? `/${locale}/client/recherche`;

  return (
    <div dir={locale === "ar" ? "rtl" : "ltr"} className="client-workspace" data-theme={theme}>
      <aside className="client-side" aria-label={c.navHome}>
        <Link href={`/${locale}/tableau-de-bord${selectedQuery}`} className="client-brand">
          <span className="client-brand-mark" aria-hidden>
            <svg viewBox="0 0 32 32" className="size-5" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M5 28V16a11 11 0 0 1 22 0v12" />
              <path d="M12 28V18a4 4 0 0 1 8 0v10" />
            </svg>
          </span>
          <span>
            <strong>Matricia</strong>
            <small>{space.space}</small>
          </span>
        </Link>
        <ClientWorkspaceNav locale={locale} selectedQuery={selectedQuery} messagesUnread={messagesUnread} active={active} />
        <p className="client-side-foot"><span aria-hidden>◆</span>{c.brandFooter}</p>
      </aside>
      <div className="client-frame">
        <div className="client-scene" aria-hidden>
          <div className="client-scene-arch" />
          <div className="client-scene-palms" />
          <div className="client-scene-pattern" />
        </div>
        <div className="client-topbar">
          <form className="client-top-search client-shell-search" method="get" action={searchPath} role="search" aria-label={c.searchLabel}>
            {selectedOrganizationId ? <input type="hidden" name="organizationId" value={selectedOrganizationId} /> : null}
            <Search aria-hidden className="size-4" />
            <label className="sr-only" htmlFor="client-shell-search">{c.searchLabel}</label>
            <input id="client-shell-search" name="q" defaultValue={searchQuery} placeholder={c.searchSpace} />
          </form>
          <Link href={`/${locale}/notifications${selectedQuery}`} className="client-icon-btn" aria-label={c.notifications}><Bell className="size-4" /></Link>
          <span className="client-space-chip"><Building2 className="size-3.5" aria-hidden />{space.space}</span>
          <span className="client-account" aria-label={c.accountMenu}><span className="client-chip">{userEmail?.slice(0, 1).toUpperCase() ?? "M"}</span></span>
        </div>
        {title ? (
          <header className="client-mast">
            <div>
              <p className="client-space-label">{space.space}</p>
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
