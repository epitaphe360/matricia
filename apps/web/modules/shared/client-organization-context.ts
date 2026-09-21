import { z } from "zod";

const uuid = z.string().uuid();

export type ClientOrganizationMembership = {
  organization_id: string;
};

export type ClientOrganizationContextResult<T extends ClientOrganizationMembership> =
  | { status: "success"; membership: T }
  | { status: "error"; reason: "NO_CLIENT_ORGANIZATION" | "ORGANIZATION_SELECTION_REQUIRED" | "FORBIDDEN_ORGANIZATION" };

/**
 * Selects an organization only from memberships already authorized by the
 * repository query. URL input is a preference, never an authorization source.
 */
export function resolveClientOrganizationContext<T extends ClientOrganizationMembership>(
  memberships: T[],
  requestedOrganizationId?: string,
): ClientOrganizationContextResult<T> {
  const unique = [...new Map(memberships.map((membership) => [membership.organization_id, membership])).values()];

  if (requestedOrganizationId !== undefined) {
    if (!uuid.safeParse(requestedOrganizationId).success) return { status: "error", reason: "FORBIDDEN_ORGANIZATION" };
    const selected = unique.find((membership) => membership.organization_id === requestedOrganizationId);
    return selected ? { status: "success", membership: selected } : { status: "error", reason: "FORBIDDEN_ORGANIZATION" };
  }

  if (unique.length === 0) return { status: "error", reason: "NO_CLIENT_ORGANIZATION" };
  if (unique.length > 1) return { status: "error", reason: "ORGANIZATION_SELECTION_REQUIRED" };
  return { status: "success", membership: unique[0]! };
}
