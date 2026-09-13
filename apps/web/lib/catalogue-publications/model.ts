import { z } from "zod";

export const publicationUuidSchema = z.string().uuid();
export const releaseKeySchema = z.string().trim().regex(/^[A-Z][A-Z0-9_.-]{2,119}$/u);
export const releaseStatusSchema = z.enum([
  "DRAFT", "IN_REVIEW", "APPROVED", "SCHEDULED", "PUBLISHING", "PUBLISHED",
  "FAILED", "DEAD_LETTER", "CANCELLED", "RETIRED", "ARCHIVED",
]);

export const rollbackInputSchema = z.object({
  libraryId: publicationUuidSchema,
  targetReleaseId: publicationUuidSchema,
  releaseKey: releaseKeySchema,
  expectedLibraryRowVersion: z.coerce.number().int().positive(),
  idempotencyKey: publicationUuidSchema,
  correlationId: publicationUuidSchema,
}).strict();

export type PublicationRelease = {
  id: string;
  libraryId: string;
  releaseKey: string;
  status: z.infer<typeof releaseStatusSchema>;
  snapshotHash: string | null;
  basedOnReleaseId: string | null;
  rollbackTargetReleaseId: string | null;
  requiresCentralApproval: boolean;
  effectiveFrom: string;
  createdAt: string;
  approvedAt: string | null;
  publishedAt: string | null;
  retiredAt: string | null;
  rowVersion: number;
};

export type PublicationLibrary = {
  id: string;
  code: string;
  status: string;
  rowVersion: number;
  currentReleaseId: string | null;
  releases: PublicationRelease[];
};

export type PublicationDashboard = {
  aal: "aal1" | "aal2";
  canRollback: boolean;
  historyTruncated: boolean;
  libraries: PublicationLibrary[];
};

export type PublicationError = "UNAUTHENTICATED" | "FORBIDDEN" | "AAL2_REQUIRED" | "INVALID_INPUT" | "INVALID_RESPONSE" | "CONFLICT" | "UNAVAILABLE";
export type PublicationResult<T> = { status: "success"; value: T } | { status: "error"; reason: PublicationError };
