import { z } from "zod";

export const uuid = z.string().uuid();
export const sha256 = z.string().regex(/^[0-9a-f]{64}$/);
export const commandKey = z.string().uuid();
export const consentPurpose = z.enum(["SOCIAL_PUBLISHING", "MARKETING_ANALYTICS", "PERSONAL_DATA_CONTENT"]);
export const campaignMode = z.enum(["MANUAL", "ASSISTED", "AUTOPILOT"]);

export const consentInput = z.object({ organizationId: uuid, purpose: consentPurpose, decision: z.enum(["GRANTED", "WITHDRAWN"]), policyVersion: z.string().trim().min(1).max(100), evidenceHash: sha256, idempotencyKey: commandKey });
export const campaignInput = z.object({ organizationId: uuid, brandKitVersionId: uuid, mode: campaignMode, titleFr: z.string().trim().min(3).max(200), titleAr: z.string().trim().min(2).max(200), frequencyMaxWeekly: z.coerce.number().int().min(1).max(50), riskThreshold: z.coerce.number().int().min(0).max(100), audienceSnapshot: z.record(z.string(), z.unknown()), sourceSnapshot: z.record(z.string(), z.unknown()), idempotencyKey: commandKey });
export const approvalInput = z.object({ campaignId: uuid, rowVersion: z.coerce.number().int().positive(), idempotencyKey: commandKey });
export const scheduleInput = z.object({ campaignId: uuid, contentVersionId: uuid, socialConnectionId: uuid, scheduledAt: z.string().datetime({ offset: true }), rowVersion: z.coerce.number().int().positive(), idempotencyKey: commandKey });

export type MarketingDashboard = {
  organizations: Array<{ id: string; name: string }>;
  consents: Array<{ organizationId: string; purpose: z.infer<typeof consentPurpose>; decision: "GRANTED" | "WITHDRAWN"; policyVersion: string; decidedAt: string }>;
  brandVersions: Array<{ id: string; organizationId: string; version: number; status: string; tradeName: string }>;
  connections: Array<{ id: string; organizationId: string; provider: "LINKEDIN" | "META"; status: string }>;
  campaigns: Array<{ id: string; organizationId: string; mode: z.infer<typeof campaignMode>; titleFr: string; titleAr: string; status: string; frequencyMaxWeekly: number; riskThreshold: number; rowVersion: number; approvedAt: string | null }>;
  contents: Array<{ id: string; campaignId: string; channel: "LINKEDIN" | "FACEBOOK" | "INSTAGRAM" | "REEL"; versionId: string; language: "FR" | "AR"; hook: string; body: string; cta: string; hashtags: string[]; riskScore: number; status: string; expiresAt: string | null }>;
  calendar: Array<{ id: string; campaignId: string; contentVersionId: string; scheduledAt: string; status: string }>;
  performance: Array<{ campaignId: string; published: string; impressions: string; clicks: string; leads: string; attributedValueMinor: string; marketingCostMinor: string; feedback: string }>;
};

export function parseJsonObject(value: string) { try { const parsed: unknown = JSON.parse(value); return z.record(z.string(), z.unknown()).safeParse(parsed); } catch { return { success: false as const }; } }
export function formatMinor(value: string, currency: string, locale: "fr" | "ar") { const minor = BigInt(value), zero = BigInt(0), hundred = BigInt(100), negative = minor < zero, absolute = negative ? -minor : minor; return `${negative ? "−" : ""}${(absolute / hundred).toLocaleString(locale === "ar" ? "ar-MA" : "fr-MA")},${(absolute % hundred).toString().padStart(2, "0")}\u00a0${currency}`; }
