import { z } from "zod";

export const recurringUuid = z.string().uuid();
export const recurringLocale = z.enum(["fr", "ar"]);
export const requestStatus = z.enum(["DRAFT", "INFORMATION_REQUIRED", "READY", "MATCHING", "RFQ_OPEN", "QUOTES_RECEIVED", "CLIENT_REVIEW", "PROVIDER_SELECTED", "CONTRACT_PENDING", "CONTRACTED", "CANCELLED", "EXPIRED", "NO_PROVIDER_AVAILABLE"]);
export const planStatus = z.enum(["ACTIVE", "PAUSED", "ENDED"]);
export const cadence = z.enum(["MONTHLY", "QUARTERLY", "ANNUALLY"]);
export const transitionAction = z.enum(["PAUSE", "RESUME", "END"]);
export const clientRecurringRole = z.enum(["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_VIEWER"]);
export const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/u);
export const commandKey = z.string().min(8).max(200);
export const reason = z.string().trim().min(3).max(500);

export const cloneInput = z.object({
  sourceRequestId: recurringUuid,
  desiredDate: z.union([isoDate, z.literal("")]),
  reason,
  idempotencyKey: commandKey,
  correlationId: recurringUuid,
});

export const createPlanInput = z.object({
  templateRequestId: recurringUuid,
  cadence,
  startsOn: isoDate,
  endsOn: z.union([isoDate, z.literal("")]),
  reason,
  idempotencyKey: commandKey,
  correlationId: recurringUuid,
}).refine((value) => value.endsOn === "" || value.endsOn >= value.startsOn, { path: ["endsOn"] });

export const transitionPlanInput = z.object({
  planId: recurringUuid,
  action: transitionAction,
  expectedRowVersion: z.coerce.number().int().positive(),
  reason,
  idempotencyKey: commandKey,
  correlationId: recurringUuid,
});

export const generateInput = z.object({
  planId: recurringUuid,
  throughDate: isoDate,
  maxOccurrences: z.coerce.number().int().min(1).max(24),
  idempotencyKey: commandKey,
  correlationId: recurringUuid,
});

export type RecurringRequest = {
  id: string;
  canManage: boolean;
  status: z.infer<typeof requestStatus>;
  description: string;
  desiredDate: string | null;
  versionNumber: number;
  createdAt: string;
};

export type RecurringOccurrence = { id: string; scheduledOn: string; generatedRequestId: string; createdAt: string };
export type RecurringPlan = {
  id: string;
  canManage: boolean;
  templateRequestId: string;
  status: z.infer<typeof planStatus>;
  rowVersion: number;
  currentVersion: number;
  cadence: z.infer<typeof cadence>;
  startsOn: string;
  endsOn: string | null;
  reason: string;
  updatedAt: string;
  occurrences: RecurringOccurrence[];
};
export type ClientRecurringRole = z.infer<typeof clientRecurringRole>;
export type RecurringDashboard = { access: { activeRole: ClientRecurringRole; canManage: boolean }; requests: RecurringRequest[]; plans: RecurringPlan[] };
