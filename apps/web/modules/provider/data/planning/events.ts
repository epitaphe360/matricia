import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { ProviderMissionDashboard } from "@/modules/provider/data/missions/model";
import type { ProviderDashboard } from "@/modules/provider/data/qualification/model";
import type { ProviderQuoteDashboard } from "@/modules/provider/data/quotes/model";

export const PLANNING_TIME_ZONE = "Africa/Casablanca";

export type PlanningKind = "consultation" | "quote" | "milestone" | "document";

export type PlanningEvent = {
  id: string;
  kind: PlanningKind;
  kindLabel: string;
  label: string;
  dueAt: string;
  href: string;
};

const kindLabels: Record<Locale, Record<PlanningKind, string>> = {
  fr: { consultation: "Consultation", quote: "Devis", milestone: "Jalon", document: "Document" },
  ar: { consultation: "استشارة", quote: "عرض", milestone: "معلم", document: "وثيقة" },
};

export function ymdInZone(iso: string, timeZone = PLANNING_TIME_ZONE): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(iso));
}

export function eventCalendarDay(dueAt: string, timeZone = PLANNING_TIME_ZONE): string {
  const dateOnly = /^(\d{4}-\d{2}-\d{2})T00:00:00/u.exec(dueAt);
  if (dateOnly) return dateOnly[1]!;
  return ymdInZone(dueAt, timeZone);
}

export function addCalendarDays(ymd: string, days: number): string {
  const [year, month, day] = ymd.split("-").map(Number);
  const next = new Date(Date.UTC(year!, month! - 1, day! + days, 12));
  return next.toISOString().slice(0, 10);
}

export function mondayOnOrBefore(ymd: string): string {
  const [year, month, day] = ymd.split("-").map(Number);
  const utc = new Date(Date.UTC(year!, month! - 1, day, 12));
  const weekday = utc.getUTCDay();
  return addCalendarDays(ymd, weekday === 0 ? -6 : 1 - weekday);
}

export function weekDays(monday: string): string[] {
  return Array.from({ length: 7 }, (_, index) => addCalendarDays(monday, index));
}

export function isAllDayEvent(dueAt: string): boolean {
  return /T00:00:00/u.test(dueAt);
}

export function eventHourLabel(dueAt: string, locale: Locale, timeZone = PLANNING_TIME_ZONE): string | null {
  if (isAllDayEvent(dueAt)) return null;
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(dueAt));
}

export function collectPlanningEvents(input: {
  locale: Locale;
  organizationQuery: string;
  quotes: { status: "success"; dashboard: ProviderQuoteDashboard } | { status: "error" };
  missions: { status: "success"; dashboard: ProviderMissionDashboard } | { status: "error" };
  qualification: { status: "success"; dashboard: ProviderDashboard } | { status: "error" };
}): PlanningEvent[] {
  const labels = kindLabels[input.locale];
  const events: PlanningEvent[] = [];
  if (input.quotes.status === "success") {
    const orgQuery = input.organizationQuery || `?organizationId=${input.quotes.dashboard.organizationId}`;
    for (const invite of input.quotes.dashboard.invitations) {
      if (["INVITED", "VIEWED", "ACCEPTED"].includes(invite.status)) {
        events.push({
          id: `invite:${invite.id}`,
          kind: "consultation",
          kindLabel: labels.consultation,
          label: invite.description,
          dueAt: invite.deadline,
          href: `/${input.locale}/sous-traitant/consultations/${invite.id}${orgQuery}`,
        });
      }
      if (invite.quote && ["DRAFT", "SUBMITTED", "REVISED"].includes(invite.quote.status)) {
        events.push({
          id: `quote:${invite.quote.id}`,
          kind: "quote",
          kindLabel: labels.quote,
          label: `${invite.description} · ${invite.quote.status}`,
          dueAt: invite.deadline,
          href: `/${input.locale}/sous-traitant/devis/${invite.quote.id}${orgQuery}`,
        });
      }
    }
  }
  if (input.missions.status === "success") {
    for (const mission of input.missions.dashboard.missions) {
      for (const milestone of mission.milestones) {
        if (milestone.dueAt && !["DONE", "COMPLETED"].includes(milestone.status)) {
          events.push({
            id: `ms:${milestone.id}`,
            kind: "milestone",
            kindLabel: labels.milestone,
            label: milestone.title,
            dueAt: milestone.dueAt,
            href: `/${input.locale}/sous-traitant/missions/${mission.id}`,
          });
        }
      }
    }
  }
  if (input.qualification.status === "success") {
    for (const document of input.qualification.dashboard.documents) {
      if (document.expiresOn) {
        events.push({
          id: `doc:${document.id}`,
          kind: "document",
          kindLabel: labels.document,
          label: `${document.code} · ${document.status}`,
          dueAt: `${document.expiresOn}T00:00:00.000Z`,
          href: `/${input.locale}/sous-traitant/qualification#documents`,
        });
      }
    }
  }
  return events.sort((left, right) => Date.parse(left.dueAt) - Date.parse(right.dueAt));
}

export function eventsForDay(events: readonly PlanningEvent[], day: string): PlanningEvent[] {
  return events.filter((event) => eventCalendarDay(event.dueAt) === day);
}

export function planningKindLabel(locale: Locale, kind: PlanningKind): string {
  return kindLabels[locale][kind];
}
