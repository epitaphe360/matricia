import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { loadRewardsDashboard } from "@/lib/rewards-referrals-roi/repository";
import { cn } from "@/lib/utils";
import { getValueMessages } from "./messages";
import { ValuePanel } from "./value-panel";

export default async function RewardsPage({ params, searchParams }: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const result = await loadRewardsDashboard(organizationId);
  const messages = getValueMessages(locale);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const organizationQuery = organizationId ? `?organizationId=${encodeURIComponent(organizationId)}` : "";
  return <main dir={locale === "ar" ? "rtl" : "ltr"} className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-7xl space-y-7">
    <nav aria-label={messages.navigation} className="flex justify-between gap-3"><Link href={`/${locale}/tableau-de-bord${organizationQuery}`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/client/recompenses${organizationQuery}`} hrefLang={alternate} className="min-h-11 px-3 py-2 font-medium text-primary">{messages.language}</Link></nav>
    <header><h1 className="text-3xl font-semibold sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-4xl leading-7 text-muted-foreground">{messages.intro}</p></header>
    {result.status === "error" ? <Alert variant={result.reason === "NO_ORGANIZATION" || result.reason === "ORGANIZATION_SELECTION_REQUIRED" ? "default" : "destructive"}><AlertTitle>{result.reason === "NO_ORGANIZATION" || result.reason === "ORGANIZATION_SELECTION_REQUIRED" ? messages.noOrg : messages.loadError}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert> : <ValuePanel dashboard={result.dashboard} locale={locale} m={messages}/>}</div></main>;
}
