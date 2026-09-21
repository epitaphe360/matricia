import Link from "next/link";
import { clientDashboardCopy } from "@/modules/client/data/home/copy";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import {
  buildClientPrimaryNav,
  buildClientUtilityNav,
  type ClientNavItem,
  type ClientNavKey,
} from "@/modules/client/ui/client-nav";

function NavList({ items, active, label }: { items: ClientNavItem[]; active?: ClientNavKey; label: string }) {
  return (
    <nav className="client-side-nav" aria-label={label}>
      {items.map((item) => {
        const Icon = item.icon;
        return (
          <Link key={item.key} href={item.href} data-active={active && item.key === active ? "true" : undefined}>
            <Icon aria-hidden className="size-4" />
            {item.label}
            {item.badge ? <span className="client-nav-dot" aria-hidden /> : null}
          </Link>
        );
      })}
    </nav>
  );
}

export function ClientWorkspaceNav({
  locale,
  selectedQuery,
  messagesUnread,
  active,
}: {
  locale: Locale;
  selectedQuery: string;
  messagesUnread?: boolean;
  active?: ClientNavKey;
}) {
  const c = clientDashboardCopy[locale];
  return (
    <>
      <NavList items={buildClientPrimaryNav({ locale, selectedQuery, messagesUnread })} active={active} label={c.navHome} />
      <p className="client-side-nav-label">{c.navMore}</p>
      <NavList items={buildClientUtilityNav({ locale, selectedQuery })} active={active} label={c.navMore} />
    </>
  );
}
