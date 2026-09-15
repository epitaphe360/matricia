import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { loadSubscriptionDashboard } from "@/lib/subscriptions/repository";
import { cn } from "@/lib/utils";
import { getSubscriptionMessages } from "./messages";
import { SubscriptionPanel } from "./subscription-panel";

export default async function SubscriptionPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const result = await loadSubscriptionDashboard(organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getSubscriptionMessages(locale);
  if (result.status === "error") return <main className="min-h-dvh bg-muted/40 px-4 py-8"><p role="alert" className="mx-auto max-w-5xl rounded-lg border border-destructive/40 p-4 text-destructive">{messages.error}</p></main>;
  const keys = Object.fromEntries(["trial", ...result.dashboard.plans.map((plan) => plan.id)].map((key) => [key, randomUUID()]));
  const alternate = locale === "fr" ? "ar" : "fr";
  const organizationQuery = organizationId ? `?organizationId=${encodeURIComponent(organizationId)}` : "";
  return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}>
    <div className="mx-auto max-w-6xl space-y-6">
      <nav aria-label="Navigation" className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/tableau-de-bord${organizationQuery}`} className={cn(buttonVariants({variant:"outline"}),"min-h-11")}>{locale==="ar"?"لوحة التحكم":"Tableau de bord"}</Link><Link href={`/${alternate}/client/abonnement${organizationQuery}`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{locale==="ar"?"Français":"العربية"}</Link></nav>
      <header><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1><p className="mt-2 max-w-3xl text-muted-foreground">{messages.description}</p><p className="mt-2 font-medium">{result.dashboard.organizationName}</p></header>
      <SubscriptionPanel dashboard={result.dashboard} locale={locale} messages={messages} keys={keys} />
    </div>
  </main>;
}
