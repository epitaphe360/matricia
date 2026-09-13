import type { RuleSimulation, RuleValidationReport, RuleValidationWorkspace } from "./model";

export type RuleValidationError = "UNAUTHENTICATED" | "FORBIDDEN" | "INVALID_INPUT" | "INVALID_RESPONSE" | "UNAVAILABLE";
export type RuleValidationResult<T> = { status: "success"; value: T } | { status: "error"; reason: RuleValidationError };

export type QueryResponse = { data: unknown; error: { code?: string; message?: string } | null };
export type RuleValidationDependencies = {
  access(): Promise<"AUTHORIZED" | "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE">;
  versions(): Promise<QueryResponse>;
  questions(questionnaireVersionId: string): Promise<QueryResponse>;
  rpc(name: string, input: Record<string, unknown>): Promise<QueryResponse>;
};

export interface RuleValidationRepository {
  loadWorkspace(selectedVersionId: string | null): Promise<RuleValidationResult<RuleValidationWorkspace>>;
  validate(questionnaireVersionId: string): Promise<RuleValidationResult<RuleValidationReport>>;
  simulate(input: { questionnaireVersionId: string; answers: Record<string, unknown>; previousAnswers: Record<string, unknown> }): Promise<RuleValidationResult<RuleSimulation>>;
}
