import Link from "next/link";
import { buttonVariants } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getPublicSiteCopy } from "./public-copy";

const paths = [
  ["home", ""],
  ["services", "services"],
  ["franchise", "franchise"],
  ["about", "a-propos"],
  ["contact", "contact"],
] as const;

export function PublicNavigation({ locale }: { locale: Locale }) {
  const copy = getPublicSiteCopy(locale);
  const links = paths.map(([key, path]) => ({ label: copy[key], href: `/${locale}${path ? `/${path}` : ""}` }));

  return <header dir={locale === "ar" ? "rtl" : "ltr"} className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/85">
    <div className="mx-auto flex min-h-16 max-w-7xl items-center justify-between gap-3 px-4 sm:px-6">
      <Link href={`/${locale}`} aria-label={copy.brandLabel} className="rounded-md text-xl font-semibold tracking-tight text-primary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2">Matricia</Link>
      <nav aria-label={copy.navigationLabel} className="hidden items-center gap-1 sm:flex">
        {links.map(link => <Link key={link.href} href={link.href} className="min-h-11 rounded-md px-3 py-3 text-sm font-medium text-foreground/80 transition-colors hover:bg-accent hover:text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{link.label}</Link>)}
        <Link href={`/${locale}/connexion`} className={cn(buttonVariants(), "ms-2 min-h-11")}>{copy.signIn}</Link>
      </nav>
      <details className="group relative sm:hidden">
        <summary className={cn(buttonVariants({ variant: "outline" }), "min-h-11 cursor-pointer list-none marker:content-none")}>{copy.menu}</summary>
        <nav aria-label={copy.navigationLabel} className="absolute end-0 z-50 mt-2 w-64 rounded-xl border bg-popover p-2 text-popover-foreground shadow-lg">
          <ul className="space-y-1">
            {links.map(link => <li key={link.href}><Link href={link.href} className="flex min-h-11 items-center rounded-md px-3 py-2 text-sm font-medium hover:bg-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{link.label}</Link></li>)}
            <li><Link href={`/${locale}/connexion`} className={cn(buttonVariants(), "mt-1 min-h-11 w-full")}>{copy.signIn}</Link></li>
          </ul>
        </nav>
      </details>
    </div>
  </header>;
}
