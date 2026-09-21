import { listInvitations, type InvitationOrganization, type SafeInvitation } from "@/app/[locale]/invitations/actions";
import { loadAdminClients } from "@/modules/admin/data/clients/repository";
import { loadAdminOrganizationFiche, loadAdminSupervisionDashboard } from "@/modules/admin/data/supervision/repository";
import type { AdminOrganizationFiche, AdminSupervisionDashboard } from "@/modules/admin/data/supervision/types";
import { canApplyAdminDemo, demoActorUsers as overlayActorUsers, demoClientCases, demoClientOrganizations, demoDiagnostics, demoSupervisionOrganizations } from "./demo-overlay";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { inferOrgType } from "./directory";

export type ActorUserRow = {
  userId: string;
  membershipId: string;
  organizationId: string;
  organizationName: string;
  roles: string[];
  status: string;
  updatedAt: string | null;
};

export type ActorDirectory = {
  organizations: AdminSupervisionDashboard["organizations"];
  users: ActorUserRow[];
  invites: SafeInvitation[];
  inviteOrganizations: InvitationOrganization[];
  forbidden: boolean;
};

export async function loadAdminActorDirectory(): Promise<ActorDirectory> {
  const [supervision, invitations] = await Promise.all([loadAdminSupervisionDashboard(80), listInvitations()]);
  let organizations = supervision.status === "success" ? supervision.value.organizations : [];
  const inviteOrganizations = invitations.status === "success" ? invitations.organizations : [];
  const invites = invitations.status === "success" ? invitations.invitations.filter((item) => item.status === "PENDING" && item.direction === "MANAGED") : [];
  const fiches = await Promise.all(organizations.slice(0, 16).map((org) => loadAdminOrganizationFiche(org.id)));
  const users: ActorUserRow[] = [];
  for (const fiche of fiches) {
    if (fiche.status !== "success") continue;
    for (const membership of fiche.value.memberships) {
      users.push({
        userId: membership.user_id,
        membershipId: membership.id,
        organizationId: fiche.value.organization.id,
        organizationName: fiche.value.organization.display_name,
        roles: membership.roles,
        status: membership.status,
        updatedAt: fiche.value.organization.updated_at,
      });
    }
  }
  let forbidden = supervision.status === "error" && supervision.reason === "FORBIDDEN";
  if (canApplyAdminDemo()) {
    if (organizations.length === 0) organizations = demoSupervisionOrganizations;
    if (users.length === 0) users.push(...overlayActorUsers());
    forbidden = false;
  }
  return {
    organizations,
    users,
    invites,
    inviteOrganizations,
    forbidden,
  };
}

export async function loadAdminActorUser(userId: string): Promise<{
  rows: ActorUserRow[];
  fiche: AdminOrganizationFiche | null;
  organizations: AdminSupervisionDashboard["organizations"];
}> {
  const directory = await loadAdminActorDirectory();
  const rows = directory.users.filter((row) => row.userId === userId);
  const first = rows[0];
  const fiche = first ? await loadAdminOrganizationFiche(first.organizationId) : null;
  return {
    rows,
    fiche: fiche?.status === "success" ? fiche.value : null,
    organizations: directory.organizations,
  };
}

export function memberLabel(locale: Locale, organizationName: string) {
  return locale === "ar" ? `عضو · ${organizationName}` : `Membre · ${organizationName}`;
}

export function demoActorUsers(): ActorUserRow[] {
  if (!canApplyAdminDemo()) return [];
  return overlayActorUsers();
}

export async function loadAdminClientDirectory(locale: Locale) {
  const [supervision, clients] = await Promise.all([loadAdminSupervisionDashboard(100), loadAdminClients(locale)]);
  let organizations = supervision.status === "success"
    ? supervision.value.organizations.filter((org) => inferOrgType(`${org.display_name} ${org.legal_name}`, locale) === (locale === "ar" ? "عميل" : "Client"))
    : [];
  let cases = clients.status === "success" ? clients.dashboard.cases : [];
  let diagnostics = supervision.status === "success" ? supervision.value.diagnostics : [];
  let reason = clients.status === "error" ? clients.reason : supervision.status === "error" ? supervision.reason : null;
  if (canApplyAdminDemo()) {
    if (organizations.length === 0) organizations = demoClientOrganizations(locale);
    if (cases.length === 0) cases = demoClientCases();
    if (diagnostics.length === 0) diagnostics = demoDiagnostics();
    if (reason === "FORBIDDEN") reason = null;
  }
  return {
    organizations,
    cases,
    diagnostics,
    dashboard: clients.status === "success" ? clients.dashboard : null,
    reason,
    keys: clients.status === "success"
      ? Object.fromEntries(clients.dashboard.cases.flatMap((item) => [
        [`case:${item.id}`, crypto.randomUUID()],
        ...item.documents.map((document) => [`document:${document.id}`, crypto.randomUUID()] as const),
        ...item.questions.map((question) => [`response:${question.id}`, crypto.randomUUID()] as const),
      ]))
      : {} as Record<string, string>,
  };
}
