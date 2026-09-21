import Link from "next/link";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export function OrganizationTabs({
  locale,
  query,
  active,
}: {
  locale: Locale;
  query: string;
  active: "profile" | "people" | "security";
}) {
  const c = spaceCopy(locale);
  return (
    <nav className="client-tabs" aria-label={c.orgTitle}>
      <Link href={`/${locale}/organisation${query}`} aria-current={active === "profile" ? "page" : undefined}>{c.orgProfile}</Link>
      <Link href={`/${locale}/organisation${query}#sites`}>{c.sitesLocations}</Link>
      <Link href={`/${locale}/organisation/roles${query}`} aria-current={active === "people" ? "page" : undefined}>{c.people}</Link>
      <Link href={`/${locale}/organisation/roles${query}#invitations`}>{c.invitations}</Link>
      <Link href={`/${locale}/securite/compte${query}`} aria-current={active === "security" ? "page" : undefined}>{c.security}</Link>
      <Link href={`/${locale}/securite/sessions`}>{c.sessions}</Link>
    </nav>
  );
}
