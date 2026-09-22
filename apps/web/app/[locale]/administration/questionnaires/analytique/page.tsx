import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { buttonVariants } from "@/modules/shared/ui/button";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { loadQuestionnaireAbandonmentDashboard } from "@/modules/shared/lib/questionnaire-abandonment-analytics/repository";
import { cn } from "@/modules/shared/lib/utils";
import { AnalyticsDashboard } from "@/modules/admin/screens/questionnaires/analytique/analytics-dashboard";
import { getMessages } from "@/modules/admin/screens/questionnaires/analytique/messages";
import { AdminModulePage } from "@/modules/admin/ui/admin-module-page";

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const m = getMessages(locale);
  const result = await loadQuestionnaireAbandonmentDashboard();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/administration/questionnaires/analytique` }));
  return (
    <AdminModulePage locale={locale} active="catalog" path="questionnaires/analytique" title={m.title} lead={m.description}>
      {result.status === "error" ? (
        <Alert variant="destructive">
          <AlertTitle>{result.reason === "FORBIDDEN" ? m.forbidden : m.unavailable}</AlertTitle>
          <AlertDescription>
            {result.reason === "FORBIDDEN" ? m.forbiddenText : m.unavailableText}
            <div>
              <Link href={`/${locale}/administration/questionnaires/analytique`} className={cn(buttonVariants({ variant: "outline" }), "mt-4 min-h-11")}>{m.retry}</Link>
            </div>
          </AlertDescription>
        </Alert>
      ) : (
        <AnalyticsDashboard d={result.dashboard} locale={locale} m={m} />
      )}
    </AdminModulePage>
  );
}
