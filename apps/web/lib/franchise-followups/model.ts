import { z } from "zod";

export const FOLLOWUP_STAGES = ["SENT","OPENED","REGISTERED","PROFILE_STARTED","VERIFIED","DIAGNOSTIC_STARTED","OPPORTUNITY_CREATED","RFQ_STARTED"] as const;
const uuid = z.string().uuid();
const csvIntegers = z.string().trim().regex(/^\d+(?:,\d+){0,9}$/u).transform((value) => value.split(",").map(Number));

export const followupPolicyInput = z.object({
  franchiseId: uuid,
  eligibleStages: z.array(z.enum(FOLLOWUP_STAGES)).min(1).max(8),
  reminderDelaysMinutes: csvIntegers.refine((values) => values.length <= 8 && values.every((value,index) => value <= 525_600 && (index === 0 || value > (values[index - 1] ?? -1)))),
  retryDelaysMinutes: csvIntegers.refine((values) => values.length <= 10 && values.every((value,index) => value >= 1 && value <= 525_600 && (index === 0 || value > (values[index - 1] ?? 0)))),
  maximumAttempts: z.coerce.number().int().min(1).max(10),
  maximumRemindersPer7Days: z.coerce.number().int().min(1).max(8),
  leaseSeconds: z.coerce.number().int().min(30).max(900),
  effectiveFrom: z.string().datetime({ offset: true }),
  effectiveUntil: z.string().datetime({ offset: true }).or(z.literal("")),
  changeReason: z.string().trim().min(10).max(1000),
  idempotencyKey: uuid,
}).refine((value) => value.maximumAttempts <= value.retryDelaysMinutes.length + 1, { path: ["maximumAttempts"] })
  .refine((value) => !value.effectiveUntil || value.effectiveUntil > value.effectiveFrom, { path: ["effectiveUntil"] });

export const followupPreferenceInput = z.object({
  prospectId: uuid, contactAllowed: z.boolean(), emailAllowed: z.boolean(), locale: z.enum(["fr","ar"]),
  timeZone: z.string().trim().min(1).max(100), quietHoursStart: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/u),
  quietHoursEnd: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/u), maximumRemindersPer7Days: z.coerce.number().int().min(0).max(8),
  changeReason: z.string().trim().min(10).max(1000), idempotencyKey: uuid,
}).refine((value) => value.contactAllowed || !value.emailAllowed, { path: ["emailAllowed"] })
  .refine((value) => value.quietHoursStart !== value.quietHoursEnd, { path: ["quietHoursEnd"] });

export const followupDecisionInput = z.object({ policyVersionId: uuid, decision: z.enum(["APPROVE","REJECT"]), reason: z.string().trim().min(10).max(1000), idempotencyKey: uuid });

export type FollowupDashboard = Readonly<{
  currentUserId: string; canApprove: boolean;
  franchises: ReadonlyArray<{ id: string; operatorCode: string; canWrite: boolean }>;
  prospects: ReadonlyArray<{ id: string; franchiseId: string; displayName: string; type: "CLIENT"|"PROVIDER"; stage: string; nextFollowupAt: string|null; preference: null|{ id:string; version:number; contactAllowed:boolean; emailAllowed:boolean; locale:"fr"|"ar"; timeZone:string; quietStart:string; quietEnd:string; weeklyLimit:number } }>;
  policies: ReadonlyArray<{ id:string; franchiseId:string; version:number; status:"PENDING_APPROVAL"|"ACTIVE"|"REJECTED"|"RETIRED"; eligibleStages:string[]; reminderDelaysMinutes:number[]; retryDelaysMinutes:number[]; maximumAttempts:number; weeklyLimit:number; leaseSeconds:number; effectiveFrom:string; effectiveUntil:string|null; proposedBy:string; approvedBy:string|null }>;
  jobs: ReadonlyArray<{ id:string; prospectId:string; policyVersionId:string; reminderOrdinal:number; locale:"fr"|"ar"; status:"PENDING"|"LEASED"|"RETRY"|"SUCCEEDED"|"CANCELLED"|"DEAD_LETTER"; nextAttemptAt:string; attemptCount:number; lastErrorCode:string|null }>;
}>;
