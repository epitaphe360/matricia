export type EngineErrorCode =
  | "INVALID_SNAPSHOT" | "INVALID_AST" | "INVALID_REFERENCE" | "INVALID_TYPE"
  | "INVALID_REGEX" | "INVALID_DATE_TIME" | "INVALID_INPUT" | "RULE_CYCLE"
  | "ACTION_CONFLICT" | "BUDGET_EXCEEDED" | "EVALUATION_FAILED";

export class QuestionEngineError extends Error {
  readonly code: EngineErrorCode;
  readonly correlationId: string;

  constructor(code: EngineErrorCode, correlationId = "question-engine") {
    super(code);
    this.name = "QuestionEngineError";
    this.code = code;
    this.correlationId = correlationId;
  }
}
