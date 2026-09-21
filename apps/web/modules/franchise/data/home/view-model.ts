import type { FranchiseCrmDashboard } from "@/modules/franchise/data/crm/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

/**
 * Accueil de l'espace franchisé : synthèse calculée uniquement à partir du
 * dashboard CRM/performance déjà autorisé côté serveur. Aucune donnée
 * indisponible n'est remplacée par zéro.
 */
export type FranchiseHomeCounts = {
  activeProspects: number | null;
  overdueFollowups: number | null;
  openAlerts: number | null;
  criticalAlerts: number | null;
  activeObjectives: number | null;
};

export type FranchiseHomeFeedTone = "critical" | "high" | "default";

export type FranchiseHomeFeedItem = {
  id: string;
  kind: "ALERT" | "FOLLOWUP";
  severity: "INFO" | "WARNING" | "CRITICAL" | null;
  dossier: string;
  dueAt: string | null;
  owner: string;
  tone: FranchiseHomeFeedTone;
};

export function unavailableFranchiseHomeCounts(): FranchiseHomeCounts {
  return { activeProspects: null, overdueFollowups: null, openAlerts: null, criticalAlerts: null, activeObjectives: null };
}

export function computeFranchiseHomeCounts(dashboard: FranchiseCrmDashboard, now: string): FranchiseHomeCounts {
  const nowMs = Date.parse(now);
  const openAlerts = dashboard.alerts.filter((alert) => alert.status === "OPEN");
  return {
    activeProspects: dashboard.prospects.filter((prospect) => prospect.stage !== "CONTRACT_SIGNED").length,
    overdueFollowups: dashboard.prospects.filter((prospect) => prospect.nextFollowupAt !== null && Date.parse(prospect.nextFollowupAt) < nowMs).length,
    openAlerts: openAlerts.length,
    criticalAlerts: openAlerts.filter((alert) => alert.severity === "CRITICAL").length,
    activeObjectives: dashboard.objectives.filter((objective) => objective.status === "ACTIVE").length,
  };
}

const SEVERITY_RANK: Record<"CRITICAL" | "WARNING" | "INFO", number> = { CRITICAL: 0, WARNING: 1, INFO: 2 };

function alertTone(severity: "INFO" | "WARNING" | "CRITICAL"): FranchiseHomeFeedTone {
  if (severity === "CRITICAL") return "critical";
  if (severity === "WARNING") return "high";
  return "default";
}

/**
 * Flux d'activité de l'accueil : alertes ouvertes expliquées (critiques
 * d'abord), puis relances prospects triées par échéance réelle. Les deux
 * sources existent déjà dans le dashboard CRM autorisé.
 */
export function buildFranchiseHomeFeed(
  dashboard: FranchiseCrmDashboard,
  locale: Locale,
  now: string,
  limit = 8,
): FranchiseHomeFeedItem[] {
  const nowMs = Date.parse(now);
  const operatorByFranchise = new Map(dashboard.franchises.map((franchise) => [franchise.id, franchise.operatorCode]));

  const alerts: FranchiseHomeFeedItem[] = dashboard.alerts
    .filter((alert) => alert.status === "OPEN")
    .sort((left, right) => SEVERITY_RANK[left.severity] - SEVERITY_RANK[right.severity])
    .map((alert) => ({
      id: `alert:${alert.id}`,
      kind: "ALERT",
      severity: alert.severity,
      dossier: locale === "ar" ? alert.explanationAr : alert.explanationFr,
      dueAt: null,
      owner: operatorByFranchise.get(alert.franchiseId) ?? alert.franchiseId,
      tone: alertTone(alert.severity),
    }));

  const followups: FranchiseHomeFeedItem[] = dashboard.prospects
    .filter((prospect) => prospect.nextFollowupAt !== null)
    .sort((left, right) => Date.parse(left.nextFollowupAt as string) - Date.parse(right.nextFollowupAt as string))
    .map((prospect) => ({
      id: `followup:${prospect.id}`,
      kind: "FOLLOWUP",
      severity: null,
      dossier: prospect.displayName,
      dueAt: prospect.nextFollowupAt,
      owner: operatorByFranchise.get(prospect.franchiseId) ?? prospect.franchiseId,
      tone: Date.parse(prospect.nextFollowupAt as string) < nowMs ? "high" : "default",
    }));

  return [...alerts, ...followups].slice(0, limit);
}
