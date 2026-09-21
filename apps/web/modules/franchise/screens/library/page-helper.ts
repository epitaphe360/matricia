import { redirect } from "next/navigation";
import { loadFranchiseCrm } from "@/modules/franchise/data/crm/repository";
import { loadFranchiseDigest } from "@/modules/franchise/data/digest/repository";
import { loadFranchiseFollowups } from "@/modules/franchise/data/followups/repository";
import { loadFranchiseDashboard } from "@/modules/franchise/data/governance/repository";
import { loadFranchiseOperations } from "@/modules/franchise/data/operations/repository";
import { loadFranchiseCorrectivePlans } from "@/modules/franchise/data/quality/repository";
import { resolveFranchiseSpace } from "@/modules/franchise/data/spaces/context";
import { buildFranchiseSpaceBoard } from "@/modules/franchise/data/spaces/live";
import { loadFranchiseLibraryWorkspace, type FranchiseLibraryLoadResult } from "@/modules/franchise/data/library/workspace";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export async function requireFranchiseLibrary(input: { locale: Locale; organizationId?: string }) {
  const space = await resolveFranchiseSpace(input);
  if (space.status === "unauthenticated") redirect(`/${input.locale}/connexion`);
  const result = await loadFranchiseLibraryWorkspace({ locale: input.locale, organizationId: input.organizationId });
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${input.locale}/connexion`);
  return { space, result };
}

export function franchiseMandateName(result: FranchiseLibraryLoadResult): string | null {
  return result.status === "success" ? result.workspace.mandate.libraryName : null;
}

export function franchiseCommandScope(result: FranchiseLibraryLoadResult, fallbackOrganizationId: string | null) {
  if (result.status !== "success") {
    return { libraryId: null as string | null, organizationId: fallbackOrganizationId, services: [] as Array<{ id: string; title: string }> };
  }
  return {
    libraryId: result.workspace.mandate.libraryId,
    organizationId: result.workspace.mandate.operatorOrganizationId ?? fallbackOrganizationId,
    services: result.workspace.services.map((item) => ({ id: item.id, title: item.title })),
  };
}

export function franchiseSpaceLiveArgs(input: {
  locale: Locale;
  query: string;
  result: FranchiseLibraryLoadResult;
}) {
  const libraryName = franchiseMandateName(input.result);
  if (input.result.status !== "success") {
    return { locale: input.locale, query: input.query, libraryName };
  }
  const workspace = input.result.workspace;
  return {
    locale: input.locale,
    query: input.query,
    libraryName,
    libraryId: workspace.mandate.libraryId,
    operatorOrganizationId: workspace.mandate.operatorOrganizationId ?? null,
    volumeServices: workspace.services
      .filter((item) => item.command?.volumeEligible)
      .map((item) => ({ id: item.id, title: item.title, status: item.status, href: item.href })),
    catalogRules: workspace.rules.map((item) => ({
      id: item.id,
      title: item.title,
      status: item.status,
      href: item.href,
      actions: (item.ruleActions ?? []).map((action) => ({ type: action.type, target: action.target })),
    })),
  };
}

export async function loadFranchiseSpaceFromLibrary(input: {
  locale: Locale;
  query: string;
  result: FranchiseLibraryLoadResult;
}) {
  return loadFranchiseSpaceLive(franchiseSpaceLiveArgs(input));
}

export async function loadFranchiseSpaceLive(input: {
  locale: Locale;
  query: string;
  libraryName?: string | null;
  libraryId?: string | null;
  operatorOrganizationId?: string | null;
  volumeServices?: Array<{ id: string; title: string; status: string; href: string }>;
  catalogRules?: Array<{ id: string; title: string; status: string; href: string; actions?: Array<{ type: string; target?: string }> }>;
}) {
  const [crm, followups, governance, plans, digest, operations] = await Promise.all([
    loadFranchiseCrm(),
    loadFranchiseFollowups(),
    loadFranchiseDashboard(input.locale),
    loadFranchiseCorrectivePlans(),
    loadFranchiseDigest(),
    input.libraryId ? loadFranchiseOperations({ libraryId: input.libraryId, operatorOrganizationId: input.operatorOrganizationId }) : Promise.resolve(null),
  ]);
  return buildFranchiseSpaceBoard({
    locale: input.locale,
    query: input.query,
    libraryName: input.libraryName,
    crm: crm.status === "success" ? crm.dashboard : null,
    followups: followups.status === "success" ? followups.dashboard : null,
    governance: governance.status === "success" ? governance.dashboard : null,
    plans: plans.status === "success" ? plans.plans : null,
    digest: digest.status === "success" ? digest.dashboard : null,
    operations,
    volumeServices: input.volumeServices,
    catalogRules: input.catalogRules,
  });
}
