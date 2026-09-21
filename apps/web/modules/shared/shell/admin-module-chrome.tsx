import type { ReactNode } from "react";
import Link from "next/link";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { AdminProcessStrip, type ProcessStep } from "./admin-process-strip";

/** Chrome UX commun Admin : shell dynamique + bandeau état / owner / prochaine action. */
export function AdminModuleChrome({
  locale,
  title,
  eyebrow,
  lead,
  backHref,
  backLabel,
  languageHref,
  languageLabel,
  owner,
  nextAction,
  blocker,
  steps,
  children,
}: {
  locale: Locale;
  title: string;
  eyebrow: string;
  lead: string;
  backHref: string;
  backLabel: string;
  languageHref: string;
  languageLabel: string;
  owner: string;
  nextAction: string;
  blocker?: string | null;
  steps: readonly ProcessStep[];
  children: ReactNode;
}) {
  return (
    <main dir={locale === "ar" ? "rtl" : "ltr"} className="admin-shell min-h-dvh px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-7xl space-y-7">
        <nav className="flex flex-wrap justify-between gap-3">
          <Link href={backHref} className="admin-btn-outline">{backLabel}</Link>
          <Link href={languageHref} hrefLang={locale === "fr" ? "ar" : "fr"} className="admin-btn-outline">{languageLabel}</Link>
        </nav>
        <header className="admin-hero">
          <div className="admin-hero-inner !grid-cols-1">
            <div>
              <p className="admin-eyebrow">{eyebrow}</p>
              <h1>{title}</h1>
              <p className="admin-hero-lead">{lead}</p>
            </div>
          </div>
        </header>
        <AdminProcessStrip locale={locale} title={eyebrow} owner={owner} nextAction={nextAction} blocker={blocker} steps={steps} />
        {children}
      </div>
    </main>
  );
}
