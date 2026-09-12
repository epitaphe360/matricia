import type { ReactNode } from "react";
import { isLocale } from "@/lib/i18n/locale";
import { DiagnosticTools } from "./diagnostic-tools";
import { diagnosticToolMessages } from "./tool-messages";

export default async function Layout({ children, params }: { children: ReactNode; params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) return children;
  return <>{children}<aside dir={locale === "ar" ? "rtl" : "ltr"} className="bg-muted/40 px-4 pb-8 sm:px-6"><div className="mx-auto max-w-6xl"><DiagnosticTools locale={locale} m={diagnosticToolMessages[locale]}/></div></aside></>;
}
