import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { buttonVariants } from "@/components/ui/button";
import { createServerClientRfqRepository } from "@/lib/client-rfq/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getClientRfqMessages } from "../messages";
import { loadOpportunityRequestContext } from "../opportunity-context";
import { RequestForm } from "../request-form";

export default async function NewRequestPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ opportunityId?: string }> }) {
  const [{ locale }, { opportunityId }] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const result = await (await createServerClientRfqRepository()).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion?next=${encodeURIComponent(`/${locale}/client/demandes/nouvelle${opportunityId ? `?opportunityId=${opportunityId}` : ""}`)}`);
  const messages = getClientRfqMessages(locale);
  const context = opportunityId ? await loadOpportunityRequestContext(opportunityId) : null;
  const organization = context && result.status === "success" ? result.value.organizations.find((item) => item.id === context.organizationId) : null;
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-4xl space-y-5">
    <Link href={`/${locale}/client/demandes`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link>
    <Card><CardHeader><CardTitle>{messages.createTitle}</CardTitle><CardDescription>{messages.createDescription}</CardDescription></CardHeader><CardContent>
      {context && organization ? <RequestForm locale={locale} context={{ opportunityId: context.opportunityId, organizationId: context.organizationId, organizationName: organization.name, serviceName: locale === "ar" ? context.serviceNameAr : context.serviceNameFr, title: locale === "ar" ? context.titleAr : context.titleFr, description: locale === "ar" ? context.descriptionAr : context.descriptionFr }} messages={messages} /> : result.status === "error" ? <p role="alert" className="text-destructive">{messages.loadError}</p> : <div role="status" className="space-y-4"><p className="text-muted-foreground">{opportunityId ? messages.contextError : messages.contextRequired}</p><div className="flex flex-col gap-3 sm:flex-row"><Link href={`/${locale}/client/diagnostics`} className={cn(buttonVariants(), "min-h-11")}>{messages.openAnalysis}</Link><Link href={`/${locale}/client/diagnostics/assistance`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.describeNeed}</Link></div></div>}
    </CardContent></Card>
  </div></main>;
}
