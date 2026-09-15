import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { loadClientAmendments } from "@/lib/contracts-missions/amendments";
import { loadContractMissions } from "@/lib/contracts-missions/repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { AmendmentPanel } from "./amendment-panel";
import { getMissionMessages } from "./messages";
import { MilestoneDecisions } from "./milestone-decisions";
import { MissionPanel } from "./mission-panel";

export default async function ClientMissionsPage({ params, searchParams }: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const messages = getMissionMessages(locale);
  const [result, amendments] = await Promise.all([loadContractMissions(locale, organizationId), loadClientAmendments(organizationId)]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const alternate = locale === "fr" ? "ar" : "fr";
  const organizationQuery = organizationId ? `?organizationId=${encodeURIComponent(organizationId)}` : "";
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-7">
    <nav aria-label="Navigation" className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/tableau-de-bord${organizationQuery}`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/client/missions${organizationQuery}`} hrefLang={alternate} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary">{messages.language}</Link></nav>
    <header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{result.status === "success" ? result.dashboard.organizationName : "Matricia"}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{messages.title}</h1><p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p></header>
    {result.status === "error" ? <Alert variant={result.reason === "NO_CLIENT_ORGANIZATION" || result.reason === "ORGANIZATION_SELECTION_REQUIRED" ? "default" : "destructive"}><AlertTitle>{result.reason === "NO_CLIENT_ORGANIZATION" || result.reason === "ORGANIZATION_SELECTION_REQUIRED" ? messages.noOrg : messages.loadError}</AlertTitle><AlertDescription>{result.reason}</AlertDescription></Alert> : <><MissionPanel d={result.dashboard} locale={locale} m={messages}/><MilestoneDecisions dashboard={result.dashboard} locale={locale} messages={messages}/>{amendments.status === "success" && amendments.value.organizationId === result.dashboard.organizationId ? <AmendmentPanel d={amendments.value} locale={locale} keys={Object.fromEntries(amendments.value.items.flatMap((item) => [[`submit:${item.id}`, randomUUID()], [`sign:${item.id}`, randomUUID()]]))}/> : null}</>}
  </div></main>;
}
