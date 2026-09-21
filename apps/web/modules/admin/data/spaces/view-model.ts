import type { AdminWorkItem } from "@/modules/admin/data/command-center/model";
import type { AdminOrganizationFiche, AdminSupervisionDashboard } from "@/modules/admin/data/supervision/types";
import { isDemoClientHomeEnabled } from "@/modules/client/data/home/demo-scenario";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { adminCopy } from "./copy";
import { inferOrgType } from "./directory";

export type AdminOrgRow = {
  id: string;
  name: string;
  legalName: string;
  type: string;
  status: string;
  statusTone: "mint" | "sky" | "peach" | "violet";
  compliance: string;
  complianceTone: "mint" | "peach";
  plan: string;
  lastAction: string;
};

export type AdminTreatItem = {
  id: string;
  title: string;
  detail: string;
  href: string;
  tone: "sky" | "peach" | "mint" | "violet";
};

function localizeStatus(status: string, locale: Locale) {
  const c = adminCopy(locale);
  const key = status.toUpperCase();
  if (key === "ACTIVE") return c.statusActive;
  if (key === "PENDING") return c.statusPending;
  if (key === "SUSPENDED" || key === "ARCHIVED") return c.statusSuspended;
  return status;
}

export function mapAdminOrgRows(orgs: AdminSupervisionDashboard["organizations"], locale: Locale): AdminOrgRow[] {
  const c = adminCopy(locale);
  return orgs.map((org) => ({
    id: org.id,
    name: org.display_name,
    legalName: org.legal_name,
    type: inferOrgType(`${org.display_name} ${org.legal_name}`, locale),
    status: localizeStatus(org.status, locale),
    statusTone: org.status.toUpperCase() === "ACTIVE" ? "mint" : org.status.toUpperCase() === "PENDING" ? "sky" : "peach",
    compliance: org.open_disputes > 0 ? c.complianceReview : c.complianceOk,
    complianceTone: org.open_disputes > 0 ? "peach" : "mint",
    plan: c.unknownPlan,
    lastAction: org.open_disputes > 0 ? c.lastDispute : org.open_requests > 0 ? c.lastOpenRequest : c.lastCreated,
  }));
}

export function mapAdminTreatQueue(input: {
  locale: Locale;
  query: string;
  organizations: AdminSupervisionDashboard["organizations"];
  requests: AdminSupervisionDashboard["requests"];
  workItems: AdminWorkItem[];
}): AdminTreatItem[] {
  const { locale, query, organizations, requests, workItems } = input;
  const tones = ["sky", "peach", "mint", "violet"] as const;
  const fromWork = workItems.slice(0, 6).map((item, index) => ({
    id: item.id,
    title: locale === "ar" ? item.titleAr : item.titleFr,
    detail: item.resourceType,
    href: item.organizationId ? `/${locale}/administration/entreprises/${item.organizationId}${query}` : `/${locale}/administration/parcours${query}`,
    tone: tones[index % tones.length]!,
  }));
  if (fromWork.length > 0) return fromWork;
  const fromRequests = requests.slice(0, 6).map((item, index) => ({
    id: item.id,
    title: item.organization_name,
    detail: item.status,
    href: `/${locale}/administration/entreprises/${item.organization_id}${query}`,
    tone: tones[index % tones.length]!,
  }));
  if (fromRequests.length > 0) return fromRequests;
  return organizations.filter((org) => org.open_disputes > 0 || org.open_requests > 0).slice(0, 6).map((org, index) => ({
    id: org.id,
    title: org.display_name,
    detail: org.open_disputes > 0 ? adminCopy(locale).lastDispute : adminCopy(locale).lastOpenRequest,
    href: `/${locale}/administration/entreprises/${org.id}${query}`,
    tone: tones[index % tones.length]!,
  }));
}

export function demoAdminTreatQueue(locale: Locale, query: string): AdminTreatItem[] {
  if (!isDemoClientHomeEnabled()) return [];
  const fr = locale === "fr";
  return [
    { id: "d1", title: "Client · Communication", detail: fr ? "Dossier à examiner" : "ملف للمراجعة", href: `/${locale}/administration/parcours${query}`, tone: "sky" as const },
    { id: "d2", title: "Studio Atlas", detail: fr ? "Conformité à finaliser" : "امتثال للإنهاء", href: `/${locale}/administration/conformite-clients${query}`, tone: "peach" as const },
    { id: "d3", title: "Franchisé · Casablanca-Settat", detail: fr ? "Gouvernance à relire" : "حوكمة للمراجعة", href: `/${locale}/administration/territoires${query}`, tone: "mint" as const },
    { id: "d4", title: "Conseil Anfa", detail: fr ? "File opérationnelle" : "قائمة تشغيلية", href: `/${locale}/administration/command-center${query}`, tone: "violet" as const },
  ];
}

export function organizationJourney(fiche: AdminOrganizationFiche, locale: Locale) {
  const c = adminCopy(locale);
  const pending = c.pendingStep;
  return [
    { id: "signup", label: c.signIn, detail: pending, state: "done" as const },
    { id: "org", label: c.orgStep, detail: pending, state: "done" as const },
    { id: "compliance", label: c.compliance, detail: pending, state: fiche.disputes.some((item) => item.status !== "CLOSED") ? "current" as const : "done" as const },
    { id: "diag", label: c.diag, detail: pending, state: fiche.diagnostics.length > 0 ? "done" as const : "pending" as const },
    { id: "requests", label: c.requests, detail: pending, state: fiche.requests.length > 0 ? "done" as const : "pending" as const },
    { id: "missions", label: c.missions, detail: pending, state: fiche.missions.length > 0 ? "done" as const : "pending" as const },
  ];
}
