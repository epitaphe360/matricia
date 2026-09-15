"use client";
import { Globe2 } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useRef, useState } from "react";
import { buttonVariants } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getPublicSiteCopy } from "./public-copy";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";

export function PublicNavigation({ locale }: { locale: Locale }) {
  const copy = getPublicSiteCopy(locale);
  const journey = getPublicJourneyCopy(locale).nav;
  const alternate = locale === "fr" ? "ar" : "fr";
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const menuButton = useRef<HTMLButtonElement>(null);
  const alternatePath = pathname.replace(/^\/(fr|ar)(?=\/|$)/, `/${alternate}`);
  const links = [
    { label: journey.how, href: `/${locale}#comment-ca-marche` },
    { label: journey.providers, href: `/${locale}/fournisseur` },
    { label: journey.plans, href: `/${locale}/abonnements` },
  ];

  const preserveQuery = (event: React.MouseEvent<HTMLAnchorElement>) => { if (window.location.search) { event.preventDefault(); window.location.assign(alternatePath + window.location.search); } };
  return <header dir={locale === "ar" ? "rtl" : "ltr"} className="premium-nav" onKeyDown={event => { if (event.key === "Escape" && menuOpen) { setMenuOpen(false); menuButton.current?.focus(); } }}>
    <div className="premium-nav-inner">
      <Link href={`/${locale}`} aria-label={copy.brandLabel} className="flex min-h-11 items-center gap-2 rounded-md font-semibold tracking-tight text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2">
        <svg aria-hidden="true" width="35" height="35" viewBox="0 0 40 40" fill="none"><path d="M4 31 14 9l6 13 6-13 10 22M11 31l5-11 4 9 4-9 5 11" stroke="#193b35" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
        <span className="text-xl text-slate-950">Matricia</span>
      </Link>
      <nav aria-label={copy.navigationLabel} className="hidden items-center gap-1 lg:flex">
        {links.map(link => <Link key={link.href} href={link.href} className="min-h-11 rounded-md px-3 py-3 text-sm font-medium text-foreground/80 transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{link.label}</Link>)}
        <Link href={alternatePath} onClick={preserveQuery} hrefLang={alternate} lang={alternate} className="inline-flex min-h-11 items-center gap-1 rounded-md px-2 text-sm font-semibold text-foreground/70 hover:bg-accent"><Globe2 aria-hidden="true" className="size-4" />{alternate.toUpperCase()}</Link>
        <Link href={`/${locale}/connexion?mode=inscription&role=client`} className="min-h-11 rounded-md px-3 py-3 text-sm font-semibold text-blue-700 hover:bg-blue-50">{journey.register}</Link>
        <Link href={`/${locale}/connexion`} className="premium-nav-login">{journey.login}</Link>
        <Link href={`/${locale}/diagnostic`} className="premium-nav-action">{getPublicJourneyCopy(locale).home.start}<ArrowRightIcon /></Link>
      </nav>
      <div className="relative lg:hidden">
        <button ref={menuButton} type="button" aria-expanded={menuOpen} aria-controls="public-mobile-navigation" onClick={() => setMenuOpen(open => !open)} className={cn(buttonVariants({ variant: "outline" }), "premium-menu-trigger")}>{menuOpen ? (locale === "fr" ? "Fermer" : "إغلاق") : copy.menu}</button>
        {menuOpen ? <nav id="public-mobile-navigation" aria-label={copy.navigationLabel} className="absolute end-0 z-50 mt-2 w-64 rounded-xl border bg-popover p-2 text-popover-foreground shadow-lg">
          <ul className="space-y-1">
            {links.map(link => <li key={link.href}><Link href={link.href} className="flex min-h-11 items-center rounded-md px-3 py-2 text-sm font-medium hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{link.label}</Link></li>)}
            <li><Link href={alternatePath} onClick={preserveQuery} hrefLang={alternate} lang={alternate} className="flex min-h-11 items-center rounded-md px-3 py-2 text-sm font-medium hover:bg-accent">{alternate === "ar" ? "العربية" : "Français"}</Link></li>
            <li><Link href={`/${locale}/connexion?mode=inscription&role=client`} className="flex min-h-11 items-center rounded-md px-3 py-2 text-sm font-semibold text-blue-700 hover:bg-blue-50">{journey.register}</Link></li>
            <li><Link href={`/${locale}/connexion`} className={cn(buttonVariants({ variant: "outline" }), "mt-1 min-h-11 w-full")}>{journey.login}</Link></li>
            <li><Link href={`/${locale}/diagnostic`} className="premium-nav-action premium-nav-action-mobile">{getPublicJourneyCopy(locale).home.start}<ArrowRightIcon /></Link></li>
          </ul>
        </nav> : null}
      </div>
    </div>
  </header>;
}

function ArrowRightIcon() { return <svg aria-hidden="true" width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 8h10m-4-4 4 4-4 4" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"/></svg>; }
