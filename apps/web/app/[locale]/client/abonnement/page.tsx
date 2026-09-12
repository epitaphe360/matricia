import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { loadSubscriptionDashboard } from "@/lib/subscriptions/repository";
import { getSubscriptionMessages } from "./messages";
import { SubscriptionPanel } from "./subscription-panel";

export default async function SubscriptionPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await loadSubscriptionDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getSubscriptionMessages(locale);
  if (result.status === "error") return <main className="min-h-dvh bg-muted/40 px-4 py-8"><p role="alert" className="mx-auto max-w-5xl rounded-lg border border-destructive/40 p-4 text-destructive">{messages.error}</p></main>;
  const keys = Object.fromEntries(["trial", ...result.dashboard.plans.map((plan) => plan.id)].map((key) => [key, randomUUID()]));
  return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}>
    <div className="mx-auto max-w-6xl space-y-6">
      <header><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1><p className="mt-2 max-w-3xl text-muted-foreground">{messages.description}</p><p className="mt-2 font-medium">{result.dashboard.organizationName}</p></header>
      <SubscriptionPanel dashboard={result.dashboard} locale={locale} messages={messages} keys={keys} />
    </div>
  </main>;
}
