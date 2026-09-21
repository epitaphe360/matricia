import Link from "next/link";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getPublicSiteCopy } from "./public-copy";

export function PublicFooter({ locale }: { locale: Locale }) {
  const copy = getPublicSiteCopy(locale);
  const links = [
    { href: `/${locale}/a-propos`, label: copy.about },
    { href: `/${locale}/contact`, label: copy.contact },
    { href: `/${locale}#comment-ca-marche`, label: copy.how },
    { href: `/${locale}/abonnements`, label: copy.plans },
    { href: `/${locale}/franchise`, label: copy.franchise },
    { href: `/${locale}/entreprises`, label: copy.companies },
    { href: `/${locale}/mentions-legales`, label: copy.legalMentions },
    { href: `/${locale}/confidentialite`, label: copy.legalPrivacy },
    { href: `/${locale}/conditions`, label: copy.legalTerms },
    { href: `/${locale}/cookies`, label: copy.legalCookies },
  ];

  return (
    <footer dir={locale === "ar" ? "rtl" : "ltr"} className="public-footer">
      <div className="mx-auto grid max-w-7xl gap-6 px-4 py-8 sm:grid-cols-[1fr_auto] sm:px-6">
        <div>
          <p className="text-lg font-semibold text-white">Matricia</p>
          <p className="mt-2 max-w-xl text-sm leading-6 text-white/70">{copy.footerStatement}</p>
          <p className="mt-3 text-xs text-white/50">{copy.legalStatement}</p>
        </div>
        <nav aria-label={copy.footerLabel}>
          <ul className="grid grid-cols-2 gap-x-5 gap-y-1 text-sm sm:grid-cols-1">
            {links.map((link) => (
              <li key={link.href}>
                <Link className="inline-flex min-h-11 items-center rounded-md underline-offset-4 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" href={link.href}>
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </footer>
  );
}
