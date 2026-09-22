import { loadAdminGovernanceDashboard } from "@/modules/admin/data/governance-disputes/repository";
import { loadAdminProviders } from "@/modules/admin/data/providers/repository";
import type { AdminProviderDashboard, AdminProvider, AdminProviderService, AdminProviderDocument } from "@/modules/admin/data/providers/model";
import type { AdminGovernanceDashboard } from "@/modules/admin/data/governance-disputes/model";
import { loadAdminSupervisionDashboard, type AdminSupervisionDashboard } from "@/modules/admin/data/supervision/repository";
import type { AdminSpaceId } from "./admin-nav";
import { canApplyAdminDemo, buildDemoSpaceRows } from "./demo-overlay";
import { spaceHref, statusTone, type SpaceTone } from "./screen-catalog";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export type SpaceRow = {
  id: string;
  href: string;
  title: string;
  cells: string[];
  status: string;
  tone: SpaceTone;
  organizationId?: string;
  treat?: boolean;
  extras?: Record<string, string>;
};

export type SpaceSnapshot = {
  reason: "OK" | "FORBIDDEN" | "MFA_REQUIRED" | "UNAVAILABLE" | "INVALID_RESPONSE" | null;
  rows: SpaceRow[];
  treat: SpaceRow[];
  supervision: AdminSupervisionDashboard | null;
  providers: AdminProviderDashboard | null;
  governance: AdminGovernanceDashboard | null;
};

function sliceId(id: string) {
  return id.slice(0, 8);
}

export async function loadAdminSpaceSnapshot(locale: Locale, space: AdminSpaceId, query: string): Promise<SpaceSnapshot> {
  const [supervision, providers, governance] = await Promise.all([
    loadAdminSupervisionDashboard(120),
    ["providers", "qualification", "capacite", "documents"].includes(space) ? loadAdminProviders() : Promise.resolve(null),
    ["franchises", "territoires", "gouvernance", "litiges"].includes(space) ? loadAdminGovernanceDashboard(locale) : Promise.resolve(null),
  ]);

  const snapshot: SpaceSnapshot = {
    reason: null,
    rows: [],
    treat: [],
    supervision: supervision.status === "success" ? supervision.value : null,
    providers: providers && providers.status === "success" ? providers.dashboard : null,
    governance: governance && governance.status === "success" ? governance.value : null,
  };

  if (supervision.status === "error" && supervision.reason === "FORBIDDEN") snapshot.reason = "FORBIDDEN";
  if (supervision.status === "error" && (supervision.reason === "UNAVAILABLE" || supervision.reason === "INVALID_RESPONSE")) snapshot.reason = supervision.reason;
  if (providers && providers.status === "error") snapshot.reason = providers.reason === "MFA_REQUIRED" ? "MFA_REQUIRED" : providers.reason === "FORBIDDEN" ? "FORBIDDEN" : "UNAVAILABLE";
  if (governance && governance.status === "error") snapshot.reason = governance.reason === "MFA_REQUIRED" ? "MFA_REQUIRED" : governance.reason === "FORBIDDEN" ? "FORBIDDEN" : governance.reason === "INVALID_RESPONSE" ? "INVALID_RESPONSE" : "UNAVAILABLE";

  const dash = snapshot.supervision;
  const providerDash = snapshot.providers;
  const gov = snapshot.governance;

  if (space === "providers" && providerDash) {
    snapshot.rows = providerDash.providers.map((item) => providerRow(locale, query, item, providerDash));
    snapshot.treat = snapshot.rows.filter((row) => /UNDER_REVIEW|REJECTED|SUSPENDED|PENDING/.test(row.status));
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "qualification" && providerDash) {
    snapshot.rows = providerDash.services.map((item) => qualificationRow(locale, query, item));
    snapshot.treat = snapshot.rows.filter((row) => !/APPROVED/.test(row.status));
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "capacite" && providerDash) {
    snapshot.rows = providerDash.documents.map((item) => documentRow(locale, query, item));
    snapshot.treat = snapshot.rows.filter((row) => /SUBMITTED|UNDER_REVIEW|EXPIRED|REJECTED/.test(row.status));
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "franchises" && gov?.franchise) {
    snapshot.rows = gov.franchise.franchises.map((item) => {
      const label = locale === "ar" ? item.libraryNameAr : item.libraryNameFr;
      return {
        id: item.id,
        href: spaceHref(locale, "franchises", query, item.id),
        title: label,
        cells: [label, item.operatorCode, item.territoryCode, item.mandate ? `v${item.mandate.version}` : "—", item.type, item.status, item.mandate?.status ?? "—", item.status],
        status: item.status,
        tone: statusTone(item.status),
        organizationId: item.organizationId,
        treat: item.status !== "ACTIVE",
        extras: { mandateId: item.mandate?.id ?? "", type: item.type },
      };
    });
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "territoires" && gov?.franchise) {
    snapshot.rows = gov.franchise.franchises.flatMap((item) => {
      const versions = item.mandateVersions.length ? item.mandateVersions : item.mandate ? [item.mandate] : [];
      return versions.map((mandate) => ({
        id: mandate.id,
        href: spaceHref(locale, "territoires", query, mandate.id),
        title: `${item.operatorCode} · ${item.territoryCode}`,
        cells: [
          locale === "ar" ? item.libraryNameAr : item.libraryNameFr,
          item.territoryCode,
          item.libraryCode,
          `v${mandate.version}`,
          String(mandate.version),
          mandate.effectiveFrom.slice(0, 10),
          "effectiveUntil" in mandate && mandate.effectiveUntil ? String(mandate.effectiveUntil).slice(0, 10) : "—",
          mandate.status,
        ],
        status: mandate.status,
        tone: statusTone(mandate.status),
        organizationId: item.organizationId,
        treat: mandate.status !== "ACTIVE",
        extras: { franchiseId: item.id, type: item.type },
      }));
    });
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "gouvernance" && gov?.franchise) {
    snapshot.rows = gov.franchise.approvals.map((item) => {
      const franchise = gov.franchise?.franchises.find((entry) => entry.id === item.franchiseId);
      const name = franchise ? (locale === "ar" ? franchise.libraryNameAr : franchise.libraryNameFr) : sliceId(item.franchiseId);
      return {
        id: item.id,
        href: spaceHref(locale, "gouvernance", query, item.id, "decision"),
        title: item.requestType,
        cells: [sliceId(item.id), name, item.requestType, franchise?.territoryCode ?? "—", String(item.rowVersion), item.status, item.status, item.decision ? item.decision.decision : "—"],
        status: item.status,
        tone: statusTone(item.status),
        organizationId: franchise?.organizationId,
        treat: !item.decision,
        extras: { rowVersion: String(item.rowVersion), reason: item.reason },
      };
    });
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "matching" && dash?.matching?.length) {
    snapshot.rows = dash.matching.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "matching", query, item.id),
      title: item.organization_name,
      cells: [
        sliceId(item.request_id),
        item.policy_version,
        String(item.eligible_count),
        String(item.excluded_count),
        item.eligible_count > 0 ? (locale === "ar" ? "مراجعة" : "revue") : "—",
        String(item.rfq_count),
        String(item.eligible_count),
        item.status,
      ],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.organization_id,
      treat: item.rfq_count === 0 || item.eligible_count === 0,
      extras: {
        requestId: item.request_id,
        policy: item.policy_version,
        candidates: JSON.stringify(item.candidates),
      },
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "contrats" && dash?.contracts?.length) {
    snapshot.rows = dash.contracts.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "contrats", query, item.id),
      title: `${item.client_name} → ${item.provider_name}`,
      cells: [sliceId(item.id), item.mission_id ? sliceId(item.mission_id) : "—", item.client_name, item.provider_name, String(item.current_version), String(item.signature_count), item.status, item.status, item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.client_organization_id,
      extras: { missionId: item.mission_id ?? "", signatures: String(item.signature_count) },
      treat: /PENDING|DRAFT|SIGNATURE/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "avenants" && dash?.amendments?.length) {
    snapshot.rows = dash.amendments.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "avenants", query, item.id),
      title: `${item.client_name} → ${item.provider_name}`,
      cells: [sliceId(item.id), sliceId(item.contract_id), item.status, String(item.amendment_number), item.price_delta_minor, "—", "—", item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.client_organization_id,
      extras: { contractId: item.contract_id, amendment: String(item.amendment_number) },
      treat: /DRAFT|PENDING/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "documents" && dash?.documents?.length) {
    snapshot.rows = dash.documents.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "documents", query, item.id),
      title: `${item.kind} · ${item.code}`,
      cells: [item.organization_name, item.code, item.status, "—", "—", `${item.kind} v${item.version}`, item.expires_on ?? "—", item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.organization_id,
      extras: { kind: item.kind, version: String(item.version) },
      treat: /PENDING|SUBMITTED|UNDER_REVIEW|EXPIRED|REJECTED|QUARANTINED/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "messagerie" && dash?.messages) {
    snapshot.rows = dash.messages.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "messagerie", query, item.id),
      title: item.subject,
      cells: [item.client_name, item.provider_name, sliceId(item.service_request_id), "in-app", item.created_at.slice(0, 16), "—", item.status, item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.client_organization_id,
      extras: { rfqId: item.object_id, requestId: item.service_request_id, providerId: item.provider_organization_id },
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.status === "OPEN");
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "diagnostics" && dash) {
    snapshot.rows = dash.diagnostics.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "diagnostics", query, item.id),
      title: item.organization_name,
      cells: [item.organization_name, sliceId(item.id), item.rating, String(item.overall_score), item.rating, item.completed_at?.slice(0, 16) ?? "—", item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.organization_id,
      treat: !/COMPLETED|DONE|TERMINE/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if ((space === "demandes" || space === "matching") && dash) {
    snapshot.rows = dash.requests.map((item) => ({
      id: item.id,
      href: spaceHref(locale, space, query, item.id),
      title: item.organization_name,
      cells: space === "matching"
        ? [sliceId(item.id), sliceId(item.service_id), String(item.matching_runs), "—", item.matching_runs > 0 ? "revue" : "—", String(item.rfq_count), String(item.quote_count), item.status]
        : [sliceId(item.id), item.organization_name, sliceId(item.service_id), sliceId(item.library_id), "RFQ", `${item.rfq_count}`, String(item.matching_runs), String(item.quote_count), item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.organization_id,
      treat: item.matching_runs === 0 || /DRAFT|BLOCKED/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "devis" && dash) {
    snapshot.rows = dash.quotes.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "devis", query, item.id),
      title: `${item.client_name} · ${item.provider_name}`,
      cells: [sliceId(item.id), sliceId(item.request_id), item.provider_name, "1", "—", "—", "—", "—", "—", item.status, item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.provider_organization_id,
      treat: /REVIEW|PENDING|RECEIVED/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if ((space === "contrats" || space === "avenants" || space === "missions" || space === "jalons") && dash) {
    snapshot.rows = dash.missions.map((item) => ({
      id: item.id,
      href: spaceHref(locale, space, query, item.id),
      title: `${item.client_name} → ${item.provider_name}`,
      cells: space === "jalons"
        ? [sliceId(item.id), `${item.milestone_count}`, `${item.deliverable_count}`, item.provider_name, item.updated_at?.slice(0, 10) ?? "—", String(item.deliverable_count), item.status, "—", item.status]
        : space === "avenants"
          ? [sliceId(item.id), sliceId(item.contract_id), item.status, "—", "—", "—", "—", item.status]
          : space === "contrats"
            ? [sliceId(item.contract_id), sliceId(item.id), item.client_name, item.provider_name, "1", "—", item.status, item.status, item.status]
            : [sliceId(item.id), sliceId(item.contract_id), item.client_name, item.provider_name, `${item.milestone_count}`, `${item.deliverable_count}`, String(item.deliverable_count), item.status, item.status],
      status: item.status,
      tone: statusTone(item.status),
      organizationId: item.client_organization_id,
      extras: { contractId: item.contract_id, providerId: item.provider_organization_id },
      treat: /BLOCKED|PENDING|START|CLOSUR/i.test(item.status),
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "documents" && providerDash) {
    snapshot.rows = providerDash.documents.map((item) => documentRow(locale, query, item));
    snapshot.treat = snapshot.rows.filter((row) => /SUBMITTED|UNDER_REVIEW|EXPIRED/.test(row.status));
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "messagerie") {
    return overlayDemo(locale, space, query, snapshot);
  }
  if (space === "litiges" && gov) {
    snapshot.rows = gov.disputes.map((item) => ({
      id: item.id,
      href: spaceHref(locale, "litiges", query, item.id),
      title: item.obligationKey,
      cells: [sliceId(item.id), sliceId(item.missionId), item.obligationKey, item.obligationKey, item.latestDecision ? String(item.latestDecision.evidenceCount) : "—", item.status, item.reassignment?.status ?? "—", item.latestDecision?.outcome ?? "—", item.status],
      status: item.status,
      tone: item.urgency === "URGENT" ? "peach" : statusTone(item.status),
      treat: item.urgency === "URGENT" || !item.latestDecision,
      extras: { missionId: item.missionId, policy: item.policyVersion },
    }));
    snapshot.treat = snapshot.rows.filter((row) => row.treat);
    return overlayDemo(locale, space, query, snapshot);
  }

  return overlayDemo(locale, space, query, snapshot);
}

function overlayDemo(locale: Locale, space: AdminSpaceId, query: string, snapshot: SpaceSnapshot) {
  if (snapshot.reason === "MFA_REQUIRED" || snapshot.reason === "UNAVAILABLE" || snapshot.reason === "INVALID_RESPONSE" || snapshot.reason === "FORBIDDEN") {
    return snapshot;
  }
  if (snapshot.rows.length > 0 || !canApplyAdminDemo()) return snapshot;
  snapshot.rows = buildDemoSpaceRows(locale, space, query);
  snapshot.treat = snapshot.rows.filter((row) => row.treat);
  return snapshot;
}

function providerRow(locale: Locale, query: string, item: AdminProvider, dashboard: AdminProviderDashboard): SpaceRow {
  const services = dashboard.services.filter((row) => row.providerOrganizationId === item.organizationId);
  const docs = dashboard.documents.filter((row) => row.providerOrganizationId === item.organizationId);
  return {
    id: item.organizationId,
    href: `/${locale}/administration/providers/${item.organizationId}${query}`,
    title: item.organizationName,
    cells: [item.organizationName, services[0]?.serviceCode ?? "—", item.overallStatus, item.companyStatus, String(docs.length), item.partnerContractStatus, item.overallStatus],
    status: item.overallStatus,
    tone: statusTone(item.companyStatus),
    organizationId: item.organizationId,
    extras: { rowVersion: String(item.rowVersion), partner: item.partnerContractStatus },
    treat: item.companyStatus !== "VERIFIED",
  };
}

function qualificationRow(locale: Locale, query: string, item: AdminProviderService): SpaceRow {
  return {
    id: item.qualificationId ?? item.id,
    href: spaceHref(locale, "qualification", query, item.qualificationId ?? item.id, "decision"),
    title: item.providerName,
    cells: [item.providerName, item.serviceCode, item.requestStatus, item.eligible ? "éligible" : "non éligible", item.qualificationStatus, item.eligibilityReasons[0] ?? "—", item.qualificationStatus],
    status: item.qualificationStatus,
    tone: statusTone(item.qualificationStatus),
    organizationId: item.providerOrganizationId,
    extras: { serviceId: item.id, rowVersion: String(item.qualificationRowVersion ?? 1) },
    treat: item.qualificationStatus !== "APPROVED",
  };
}

function documentRow(locale: Locale, query: string, item: AdminProviderDocument): SpaceRow {
  return {
    id: item.id,
    href: spaceHref(locale, "documents", query, item.id),
    title: `${item.kind} · ${item.code}`,
    cells: [item.providerName, item.code, item.status, "—", "—", `${item.kind} v${item.version}`, item.expiresOn ?? "—", item.status],
    status: item.status,
    tone: statusTone(item.status),
    organizationId: item.providerOrganizationId,
    extras: { kind: item.kind, version: String(item.version) },
    treat: /SUBMITTED|UNDER_REVIEW|EXPIRED/.test(item.status),
  };
}

export function findSpaceRow(snapshot: SpaceSnapshot, itemId: string) {
  return snapshot.rows.find((row) => row.id === itemId) ?? snapshot.treat.find((row) => row.id === itemId) ?? null;
}
