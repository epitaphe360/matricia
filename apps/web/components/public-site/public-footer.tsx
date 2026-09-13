import Link from "next/link";
import type { Locale } from "@/lib/i18n/locale";
import { getPublicSiteCopy } from "./public-copy";

export function PublicFooter({ locale }: { locale: Locale }) {
  const copy = getPublicSiteCopy(locale);
  return <footer dir={locale === "ar" ? "rtl" : "ltr"} className="border-t border-white/10 bg-[#061c31] text-white">
    <div className="mx-auto grid max-w-7xl gap-6 px-4 py-8 sm:grid-cols-[1fr_auto] sm:px-6">
      <div><p className="text-lg font-semibold text-white">Matricia</p><p className="mt-2 max-w-xl text-sm leading-6 text-white/65">{copy.footerStatement}</p><p className="mt-3 text-xs text-white/50">{copy.legalStatement}</p></div>
      <nav aria-label={copy.footerLabel}>
        <ul className="grid grid-cols-2 gap-x-5 gap-y-1 text-sm sm:grid-cols-1">
          <li><Link className="inline-flex min-h-11 items-center rounded-md underline-offset-4 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" href={`/${locale}/services`}>{copy.services}</Link></li>
          <li><Link className="inline-flex min-h-11 items-center rounded-md underline-offset-4 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" href={`/${locale}/franchise`}>{copy.franchise}</Link></li>
          <li><Link className="inline-flex min-h-11 items-center rounded-md underline-offset-4 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" href={`/${locale}/a-propos`}>{copy.about}</Link></li>
          <li><Link className="inline-flex min-h-11 items-center rounded-md underline-offset-4 hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" href={`/${locale}/contact`}>{copy.contact}</Link></li>
        </ul>
      </nav>
    </div>
  </footer>;
}
