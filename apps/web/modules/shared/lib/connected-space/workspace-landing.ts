import type { Locale } from "@/modules/shared/lib/i18n/locale";

export const PLATFORM_ADMIN_ROLES = [
  "SUPER_ADMIN",
  "MATRICIA_ADMIN",
  "COMPLIANCE_MANAGER",
  "FINANCE_MANAGER",
  "DISPUTE_MANAGER",
  "LIBRARY_MANAGER",
  "SUPPORT_AGENT",
  "READ_ONLY_AUDITOR",
] as const;

const CLIENT_ROLES = ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_ACCOUNTING", "CLIENT_MEMBER", "CLIENT_VIEWER"] as const;
const PROVIDER_ROLES = ["PROVIDER_OWNER", "PROVIDER_MANAGER", "PROVIDER_SALES", "PROVIDER_TECHNICIAN", "PROVIDER_VIEWER", "PROVIDER_ACCOUNTING"] as const;
const FRANCHISE_ROLES = ["FRANCHISE_OWNER", "FRANCHISE_MANAGER", "FRANCHISE_EXPERT", "FRANCHISE_PROVIDER_MANAGER", "FRANCHISE_ACCOUNTING", "FRANCHISE_VIEWER"] as const;

export type WorkspaceLanding = "client" | "provider" | "franchise" | "administration";

function holdsOneOf(codes: ReadonlySet<string>, allowed: readonly string[]): boolean {
  return allowed.some((role) => codes.has(role));
}

/**
 * A membership role always wins over a platform role: an administrator who also
 * belongs to a client organization keeps the space of that organization.
 */
export function resolveWorkspaceLanding(input: {
  membershipRoleCodes: Iterable<string>;
  platformRoleCodes: Iterable<string>;
}): WorkspaceLanding {
  const membership = new Set(input.membershipRoleCodes);
  const platform = new Set(input.platformRoleCodes);
  if (holdsOneOf(membership, CLIENT_ROLES)) return "client";
  if (holdsOneOf(membership, PROVIDER_ROLES)) return "provider";
  if (holdsOneOf(membership, FRANCHISE_ROLES)) return "franchise";
  if (holdsOneOf(platform, PLATFORM_ADMIN_ROLES)) return "administration";
  return "client";
}

export function workspaceLandingPath(locale: Locale, landing: WorkspaceLanding, query = ""): string {
  if (landing === "administration") return `/${locale}/administration/command-center${query}`;
  if (landing === "franchise") return `/${locale}/franchise/accueil${query}`;
  return `/${locale}/tableau-de-bord${query}`;
}
