import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { loadFranchiseDigest } from "@/lib/franchise-digest/repository";
import { isLocale } from "@/lib/i18n/locale";
import { FranchiseDigestPanel } from "./digest-panel";
import { getFranchiseDigestMessages } from "./messages";

export default async function FranchiseDigestPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const m = getFranchiseDigestMessages(locale), result = await loadFranchiseDigest();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const keys: Record<string, string> = {};
  if (result.status === "success") for (const franchise of result.dashboard.franchises) keys[franchise.id] = randomUUID();
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-7xl space-y-7"><header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{m.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{m.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{m.subtitle}</p></header>{result.status === "error" ? <Alert variant="destructive"><AlertTitle>{result.reason === "FORBIDDEN" ? m.accessDenied : m.queryFailed}</AlertTitle><AlertDescription>{result.reason === "FORBIDDEN" ? m.forbidden : m.queryFailedBody}</AlertDescription></Alert> : <FranchiseDigestPanel dashboard={result.dashboard} locale={locale} m={m} keys={keys} />}</div></main>;
}
