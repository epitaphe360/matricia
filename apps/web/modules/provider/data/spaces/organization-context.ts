import { z } from "zod";

/** URL scope is selected only among the current actor's authorized memberships. */
export function selectProviderMembership<T extends { organization_id: string }>(memberships: readonly T[], requestedOrganizationId?: string): T | undefined {
  const unique = [...new Map(memberships.map((item) => [item.organization_id, item])).values()];
  if (requestedOrganizationId !== undefined) {
    if (!z.string().uuid().safeParse(requestedOrganizationId).success) return undefined;
    return unique.find((item) => item.organization_id === requestedOrganizationId);
  }
  return unique.length === 1 ? unique[0] : undefined;
}
