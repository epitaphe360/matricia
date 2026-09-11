"use client";

import { useParams } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { getCatalogMessages } from "./messages";

export default function CatalogLoading() {
  const params = useParams<{ locale?: string }>();
  const localeCandidate = params.locale ?? "";
  const locale = isLocale(localeCandidate) ? localeCandidate : "fr";
  const copy = getCatalogMessages(locale);
  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8" aria-busy="true" aria-live="polite">
      <span className="sr-only">{copy.loading}</span>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="h-11 w-48 animate-pulse rounded-lg bg-muted" />
        <div className="h-28 animate-pulse rounded-xl bg-muted" />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }, (_, index) => <div key={index} className="h-48 animate-pulse rounded-xl bg-muted" />)}
        </div>
      </div>
    </main>
  );
}
