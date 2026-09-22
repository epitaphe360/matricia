import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { loadProviderQuotes } from "@/modules/provider/data/quotes/repository";
import { loadProviderMissions } from "@/modules/provider/data/missions/repository";
import { loadProviderDashboard } from "@/modules/provider/data/qualification/repository";
import {
  addCalendarDays,
  collectPlanningEvents,
  mondayOnOrBefore,
  weekDays,
  ymdInZone,
} from "@/modules/provider/data/planning/events";
import { resolveProviderSpace } from "@/modules/provider/data/spaces/context";
import { PlanningWeekBoard } from "@/modules/provider/screens/planning/planning-board";
import { ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";

function requestedMonday(week: string | undefined, today: string): string {
  if (week && /^\d{4}-\d{2}-\d{2}$/u.test(week)) return mondayOnOrBefore(week);
  return mondayOnOrBefore(today);
}

export default async function ProviderPlanningPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string; week?: string }>;
}) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const space = await resolveProviderSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/sous-traitant/planning` }));
  const [quotes, missions, qualification] = await Promise.all([
    loadProviderQuotes(query.organizationId),
    loadProviderMissions(locale),
    loadProviderDashboard(),
  ]);
  const events = collectPlanningEvents({
    locale,
    organizationQuery: space.selectedQuery,
    quotes,
    missions,
    qualification,
  });
  const today = ymdInZone(new Date().toISOString());
  const monday = requestedMonday(query.week, today);
  const days = weekDays(monday);
  const org = space.selectedQuery;
  const weekQuery = (week: string) => {
    const params = new URLSearchParams(org.startsWith("?") ? org.slice(1) : org);
    params.set("week", week);
    const encoded = params.toString();
    return encoded ? `?${encoded}` : `?week=${week}`;
  };
  const copy =
    locale === "ar"
      ? { title: "التخطيط", eyebrow: "المواعيد الحقيقية", lead: "الاستشارات والعروض والمعالم وتجديد الوثائق — كل حدث يفتح ملفه.", unavailable: "تعذر تحميل جزء من المواعيد." }
      : { title: "Planning", eyebrow: "Échéances réelles", lead: "Consultations, devis, jalons et renouvellements documentaires — chaque événement ouvre son dossier.", unavailable: "Une partie des échéances est indisponible." };
  const partialFail = quotes.status === "error" || missions.status === "error" || qualification.status === "error";

  return (
    <ProviderAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="planning"
      title={copy.title}
      lead={copy.lead}
      kicker={partialFail ? copy.unavailable : copy.eyebrow}
    >
      <PlanningWeekBoard
        locale={locale}
        events={events}
        days={days}
        today={today}
        prevHref={`/${locale}/sous-traitant/planning${weekQuery(addCalendarDays(monday, -7))}`}
        nextHref={`/${locale}/sous-traitant/planning${weekQuery(addCalendarDays(monday, 7))}`}
        todayHref={`/${locale}/sous-traitant/planning${weekQuery(mondayOnOrBefore(today))}`}
      />
    </ProviderAppShell>
  );
}
