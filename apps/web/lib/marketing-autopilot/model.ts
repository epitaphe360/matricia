import { z } from "zod";

export const uuid = z.string().uuid();
export const sha256 = z.string().regex(/^[0-9a-f]{64}$/);
export const commandKey = z.string().uuid();
export const consentPurpose = z.enum(["SOCIAL_PUBLISHING", "MARKETING_ANALYTICS", "PERSONAL_DATA_CONTENT"]);
export const campaignMode = z.enum(["MANUAL", "ASSISTED", "AUTOPILOT"]);
export const marketingFeedback = z.enum(["KEEP", "INCREASE_FREQUENCY", "REDUCE_FREQUENCY", "CHANGE_TEMPLATE", "CHANGE_SERVICE_FOCUS", "PAUSE_CAMPAIGN"]);

export const consentInput = z.object({ organizationId: uuid, purpose: consentPurpose, decision: z.enum(["GRANTED", "WITHDRAWN"]), policyVersion: z.string().trim().min(1).max(100), evidenceHash: sha256, idempotencyKey: commandKey });
export const campaignInput = z.object({ organizationId: uuid, brandKitVersionId: uuid, mode: campaignMode, titleFr: z.string().trim().min(3).max(200), titleAr: z.string().trim().min(2).max(200), frequencyMaxWeekly: z.coerce.number().int().min(1).max(50), riskThreshold: z.coerce.number().int().min(0).max(100), audienceSnapshot: z.record(z.string(), z.unknown()), sourceSnapshot: z.record(z.string(), z.unknown()), idempotencyKey: commandKey });
export const approvalInput = z.object({ campaignId: uuid, rowVersion: z.coerce.number().int().positive(), idempotencyKey: commandKey });
export const scheduleInput = z.object({ campaignId: uuid, contentVersionId: uuid, socialConnectionId: uuid, scheduledAt: z.string().datetime({ offset: true }), rowVersion: z.coerce.number().int().positive(), idempotencyKey: commandKey });
export const marketingAllowedSlot = z.object({
  dayOfMonth: z.number().int().min(1).max(31),
  time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
}).strict();
export const scheduleRuleInput = z.object({
  organizationId: uuid,
  socialAccountId: uuid,
  timezone: z.string().trim().min(1).max(100),
  postsPerMonth: z.coerce.number().int().min(0).max(100),
  reelsPerMonth: z.coerce.number().int().min(0).max(100),
  generationDay: z.coerce.number().int().min(1).max(28),
  allowedSlots: z.array(marketingAllowedSlot).min(1).max(100).refine(
    (slots) => new Set(slots.map((slot) => `${slot.dayOfMonth}:${slot.time}`)).size === slots.length,
    "duplicate slots",
  ),
  maxServiceRepetition: z.coerce.number().int().min(1).max(20),
  privacyMinimumAggregate: z.coerce.number().int().min(3).max(1000),
  idempotencyKey: commandKey,
}).refine((value) => value.postsPerMonth + value.reelsPerMonth > 0, "empty calendar");
export const scheduleRuleActivationInput = z.object({ ruleId: uuid, headRowVersion: z.coerce.number().int().nonnegative(), idempotencyKey: commandKey });
export const assistedCalendarApprovalInput = z.object({ calendarId: uuid, rowVersion: z.coerce.number().int().positive(), idempotencyKey: commandKey });

export type MarketingDashboard = {
  organizations: Array<{ id: string; name: string }>;
  consents: Array<{ organizationId: string; purpose: z.infer<typeof consentPurpose>; decision: "GRANTED" | "WITHDRAWN"; policyVersion: string; decidedAt: string }>;
  brandVersions: Array<{ id: string; organizationId: string; version: number; status: string; tradeName: string }>;
  connections: Array<{ id: string; organizationId: string; provider: "LINKEDIN" | "META"; status: string }>;
  socialAccounts: Array<{ id: string; organizationId: string; connectionId: string; provider: "LINKEDIN" | "META"; displayName: string; status: string }>;
  scheduleRules: Array<{ id: string; organizationId: string; socialAccountId: string; version: number; status: string; timezone: string; postsPerMonth: number; reelsPerMonth: number; generationDay: number; allowedSlots: Array<z.infer<typeof marketingAllowedSlot>>; maxServiceRepetition: number; privacyMinimumAggregate: number; effective: boolean; headRowVersion: number }>;
  campaigns: Array<{ id: string; organizationId: string; mode: z.infer<typeof campaignMode>; titleFr: string; titleAr: string; status: string; frequencyMaxWeekly: number; riskThreshold: number; rowVersion: number; approvedAt: string | null }>;
  contents: Array<{ id: string; campaignId: string; channel: "LINKEDIN" | "FACEBOOK" | "INSTAGRAM" | "REEL"; versionId: string; language: "FR" | "AR"; hook: string; body: string; cta: string; hashtags: string[]; riskScore: number; status: string; expiresAt: string | null }>;
  calendars: Array<{ id: string; organizationId: string; scheduleRuleId: string; monthStart: string; status: string; generatedAt: string | null; approvedAt: string | null; rowVersion: number }>;
  calendar: Array<{ id: string; calendarId: string; campaignId: string; contentVersionId: string; scheduledAt: string; status: string }>;
  exceptions: Array<{ id: string; organizationId: string; campaignId: string; contentVersionId: string | null; type: string; severity: "WARNING" | "BLOCKING"; reason: string; automaticResolutionPossible: boolean; status: string; resolution: string | null; createdAt: string }>;
  performance: Array<{ campaignId: string; generated: string; published: string; failed: string; impressions: string; clicks: string; leads: string; diagnostics: string; opportunities: string; rfqs: string; contracts: string; attributedValueMinor: string; marketingCostMinor: string; feedback: z.infer<typeof marketingFeedback> }>;
};

export function parseJsonObject(value: string) { try { const parsed: unknown = JSON.parse(value); return z.record(z.string(), z.unknown()).safeParse(parsed); } catch { return { success: false as const }; } }
export function formatMinor(value: string, currency: string, locale: "fr" | "ar") { const minor = BigInt(value), zero = BigInt(0), hundred = BigInt(100), negative = minor < zero, absolute = negative ? -minor : minor; return `${negative ? "−" : ""}${(absolute / hundred).toLocaleString(locale === "ar" ? "ar-MA" : "fr-MA")},${(absolute % hundred).toString().padStart(2, "0")}\u00a0${currency}`; }
