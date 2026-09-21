import { z } from "zod";

export const ADMIN_CLIENT_LIMITS = Object.freeze({ cases: 100, documents: 300, questions: 300, responses: 600 });
export const uuid = z.string().uuid();
export const complianceDecisionInput = z.object({ caseId: uuid, decision: z.enum(["VERIFIED", "QUESTION_REQUIRED", "REJECTED"]), publicReason: z.string().trim().max(1000), idempotencyKey: uuid }).superRefine((value, context) => { if (["QUESTION_REQUIRED", "REJECTED"].includes(value.decision) && value.publicReason.length < 3) context.addIssue({ code: "custom", path: ["publicReason"], message: "REASON_REQUIRED" }); });
export const documentReviewInput = z.object({ documentId: uuid, decision: z.enum(["VERIFIED", "REJECTED", "QUARANTINED"]), verifiedSha256: z.string(), publicReason: z.string().trim().max(1000), internalReason: z.string().trim().max(2000), idempotencyKey: uuid }).superRefine((value, context) => { if (value.decision === "VERIFIED" && !/^[0-9a-f]{64}$/.test(value.verifiedSha256)) context.addIssue({ code: "custom", path: ["verifiedSha256"], message: "HASH_REQUIRED" }); if (value.decision === "REJECTED" && value.publicReason.length < 3) context.addIssue({ code: "custom", path: ["publicReason"], message: "REASON_REQUIRED" }); });
export const responseReviewInput = z.object({ questionId: uuid, accepted: z.enum(["yes", "no"]), idempotencyKey: uuid });

export type AdminClientDocument = { id: string; type: string; version: number; status: string; scanStatus: string; expiresOn: string | null; canReview: boolean };
export type AdminClientQuestion = { id: string; text: string; dueAt: string; status: string; responseVersion: number | null; responseSubmittedAt: string | null; canReview: boolean };
export type AdminClientCase = { id: string; organizationName: string; status: string; profileVersion: number | null; submittedAt: string | null; updatedAt: string; publicReason: string | null; canDecide: boolean; documents: AdminClientDocument[]; questions: AdminClientQuestion[] };
export type AdminClientsDashboard = { capabilities: { canAct: boolean; readOnly: boolean }; cases: AdminClientCase[]; limitsReached: string[] };
