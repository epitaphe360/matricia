"use client";

import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { safeReturnPath } from "@/modules/shared/lib/auth/return-path";
import { translateLocalPath } from "@/modules/shared/lib/auth/workspace-navigation";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export function ProviderLanguageLinks({ locale, fallback }: { locale: Locale; fallback: string }) {
  const pathname = usePathname();
  const params = useSearchParams();
  const query = params.toString();
  const current = safeReturnPath(`${pathname}${query ? `?${query}` : ""}`, locale) ?? fallback;
  return <nav className="client-lang-switch" aria-label={locale === "ar" ? "اللغة" : "Langue"}>
    {(["fr", "ar"] as const).map(language => <Link key={language} href={language === locale ? current : translateLocalPath(current, locale, language)} hrefLang={language} lang={language} aria-current={locale === language ? "page" : undefined}>{language.toUpperCase()}</Link>)}
  </nav>;
}
