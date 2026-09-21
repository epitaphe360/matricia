import { z } from "zod";

export const reputationDimensions = ["QUALITY", "DELIVERY", "COMPLIANCE", "RESPONSIVENESS", "SATISFACTION", "FINANCE"] as const;
export type ReputationDimension = (typeof reputationDimensions)[number];

const uuid = z.string().uuid();
export const favoriteCommandSchema = z.object({
  clientOrganizationId: uuid,
  providerOrganizationId: uuid,
  serviceId: z.union([uuid, z.literal("")]).transform((value) => value || null),
  active: z.boolean(),
  note: z.string().trim().max(500).transform((value) => value || null),
  expectedRowVersion: z.coerce.number().int().min(0),
  idempotencyKey: uuid,
});
export const revalidateFavoriteSchema = z.object({ favoriteId: uuid, requestId: uuid, idempotencyKey: uuid });

export type FeedbackAxis = { dimension: ReputationDimension; messageFr: string; messageAr: string };
export type ProviderFeedback = { rankingPosition: number; rankedQuoteCount: number; axes: FeedbackAxis[]; methodologyVersion: string; publishedAt: string };
export type ReputationSnapshot = { id: string; serviceId: string | null; serviceLabelFr: string | null; serviceLabelAr: string | null; version: number; policyVersion: string; scores: Record<Lowercase<ReputationDimension> | "overall", number>; evidenceCount: number; calculatedAt: string };
export type ProviderBadge = { evaluationId: string; code: string; labelFr: string; labelAr: string; serviceId: string | null; eligible: boolean; evaluatedBasisPoints: number; evaluationVersion: number; decision: "PUBLISHED" | "REVOKED" | null; decisionVersion: number | null; rationale: string | null; decidedAt: string | null };
export type ProviderReputationDashboard = { organizationName: string; feedback: ProviderFeedback[]; snapshots: ReputationSnapshot[]; badges: ProviderBadge[] };

export type FavoriteRevalidation = { requestId: string; eligible: boolean; reasons: string[]; checkedAt: string };
export type ClientFavorite = { id: string; providerOrganizationId: string; serviceId: string | null; serviceLabelFr: string | null; serviceLabelAr: string | null; status: "ACTIVE" | "REMOVED"; note: string | null; rowVersion: number; createdAt: string; latestRevalidation: FavoriteRevalidation | null };
export type ClientRequest = { id: string; serviceId: string; reference: string; status: string };
export type ClientFavoritesDashboard = { organizationId: string; organizationName: string; canManage: boolean; favorites: ClientFavorite[]; requests: ClientRequest[] };

export function basisPointsPercent(value: number) { return new Intl.NumberFormat("fr-MA", { style: "percent", maximumFractionDigits: 2 }).format(value / 10_000); }
export function maskedProviderReference(id: string) { return `•••• ${id.slice(-8).toUpperCase()}`; }
