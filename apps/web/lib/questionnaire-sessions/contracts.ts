import type { QuestionnaireDashboard } from "./model";

export type QuestionnaireFailure = "UNAUTHENTICATED" | "FORBIDDEN" | "INVALID_INPUT" | "INVALID_RESPONSE" | "CONFLICT" | "NOT_EDITABLE" | "NOT_SUBMITTABLE" | "REQUIRED_MISSING" | "BOUNDS_EXCEEDED" | "UNAVAILABLE";
export type QuestionnaireResult<T> = { status: "success"; value: T } | { status: "error"; reason: QuestionnaireFailure };
export type CommandIdentity = { idempotencyKey: string; correlationId: string };

export type QuestionnaireSessionsRepository = {
  load(selectedSessionId?: string, requestedOrganizationId?: string): Promise<QuestionnaireResult<QuestionnaireDashboard>>;
  start(input: CommandIdentity & { organizationId: string; questionnaireVersionId: string; locale: "fr" | "ar"; dueAt: string | null }): Promise<QuestionnaireResult<{ sessionId: string; rowVersion: number }>>;
  save(input: CommandIdentity & { sessionId: string; questionVersionId: string; expectedSessionRowVersion: number; expectedAnswerRowVersion: number; answerType: string; value: unknown }): Promise<QuestionnaireResult<{ sessionId: string; serverRowVersion: number; answerRowVersion: number }>>;
  submit(input: CommandIdentity & { sessionId: string; expectedSessionRowVersion: number }): Promise<QuestionnaireResult<{ sessionId: string; rowVersion: number; manifestHash: string }>>;
};
