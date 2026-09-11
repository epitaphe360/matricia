export const UNKNOWN = Object.freeze({ kind: "UNKNOWN" } as const);
export type Unknown = typeof UNKNOWN;
export type Truth = "TRUE" | "FALSE" | "UNKNOWN";

export type ExactInteger = Readonly<{ kind: "INTEGER"; value: string }>;
export type ExactDecimal = Readonly<{ kind: "DECIMAL"; value: string }>;
export type MoneyValue = Readonly<{ kind: "MONEY"; amountMinor: string; currency: string }>;
export type DateRangeValue = Readonly<{ kind: "DATE_RANGE"; start: string; end: string }>;
export type LocalTimeValue = Readonly<{ kind: "LOCAL_TIME"; localDate: string; localTime: string; timeZone: string; dstPolicy: "EARLIER" | "LATER" | "REJECT" }>;
export type JsonValue = null | boolean | string | ExactInteger | ExactDecimal | MoneyValue | DateRangeValue | LocalTimeValue |
  readonly JsonValue[] | Readonly<{ [key: string]: JsonValue }>;
export type AnswerValue = JsonValue | Unknown;

export type QuestionType =
  | "YES_NO" | "SINGLE_CHOICE" | "MULTIPLE_CHOICE" | "SHORT_TEXT" | "LONG_TEXT"
  | "INTEGER" | "DECIMAL" | "PERCENTAGE" | "MONEY" | "CURRENCY" | "DATE" | "DATE_RANGE"
  | "TIME" | "EMAIL" | "PHONE" | "URL" | "ADDRESS" | "GEO_AREA" | "RATING_5" | "RATING_10"
  | "QUANTITY" | "UNIT_VALUE" | "FILE" | "MULTI_FILE" | "IMAGE" | "TABLE" | "REPEATER"
  | "CONTACT" | "ORGANIZATION" | "PRODUCT_LIST" | "SITE_LIST" | "MILESTONE_LIST" | "BUDGET_BREAKDOWN";

export type Coercion = "STRING_TO_INTEGER" | "STRING_TO_DECIMAL" | "STRING_TO_BOOLEAN" | "STRING_TO_DATE";

export type NumericRounding = "HALF_UP" | "HALF_EVEN" | "DOWN" | "UP";
export type StructuredFieldType = Exclude<QuestionType, "TABLE" | "REPEATER">;
export interface StructuredFieldDefinition {
  readonly key: string;
  readonly type: StructuredFieldType;
  readonly nullable: boolean;
  readonly options?: readonly string[];
  readonly numeric?: Readonly<{ precision: number; scale: number; rounding: NumericRounding }>;
  readonly validation?: Readonly<{ minLength?: number; maxLength?: number; minItems?: number; maxItems?: number; minimum?: string; maximum?: string; pattern?: string }>;
}
export type StructuredSchema =
  | Readonly<{ version: string; kind: "TABLE"; minRows: number; maxRows: number; columns: readonly StructuredFieldDefinition[] }>
  | Readonly<{ version: string; kind: "REPEATER"; minItems: number; maxItems: number; children: readonly StructuredFieldDefinition[] }>;

export interface QuestionDefinition {
  readonly key: string;
  readonly sectionKey: string;
  readonly version: string;
  readonly type: QuestionType;
  readonly nullable: boolean;
  readonly visibleByDefault: boolean;
  readonly requiredByDefault: boolean;
  readonly requiredForQuote: boolean;
  readonly requiredForPublication: boolean;
  readonly options?: readonly string[];
  readonly coercion?: Coercion;
  readonly numeric?: Readonly<{ precision: number; scale: number; rounding: NumericRounding }>;
  readonly structured?: StructuredSchema;
  readonly validation?: Readonly<{
    minLength?: number;
    maxLength?: number;
    minItems?: number;
    maxItems?: number;
    minimum?: string;
    maximum?: string;
    pattern?: string;
  }>;
  readonly scoreMaximum?: string;
}

export type Operand = AnswerValue;
export type PredicateOperator = "EQ" | "NE" | "GT" | "LT" | "IN" | "CONTAINS" | "IS_EMPTY" |
  "IS_NOT_EMPTY" | "REGEX" | "DATE_BEFORE" | "DATE_AFTER" | "CHANGED" | "IS_UNKNOWN";

export type Condition =
  | Readonly<{ kind: "GROUP"; operator: "AND" | "OR"; children: readonly Condition[] }>
  | Readonly<{ kind: "NOT"; child: Condition }>
  | Readonly<{ kind: "PREDICATE"; operator: PredicateOperator; questionKey: string; operand?: Operand }>;

export type ActionType =
  | "BLOCK_PUBLICATION" | "BLOCK_RFQ" | "REQUIRE_QUESTION" | "OPTIONAL_QUESTION"
  | "SHOW_QUESTION" | "HIDE_QUESTION" | "SHOW_SECTION" | "HIDE_SECTION"
  | "ADD_VALIDATION_ERROR" | "ADD_SCORE" | "CREATE_ANOMALY" | "CREATE_RISK"
  | "CREATE_RECOMMENDATION" | "CREATE_OPPORTUNITY" | "ASSOCIATE_SOLUTION_LEVEL"
  | "REQUEST_DOCUMENT" | "REQUIRE_HUMAN_REVIEW" | "SUGGEST_SERVICE"
  | "START_CHILD_DIAGNOSTIC" | "SET_ANSWER_VALIDITY";

export interface RuleAction {
  readonly type: ActionType;
  readonly target?: string;
  readonly value?: string;
  readonly messageKey?: string;
}

export interface RuleDefinition {
  readonly key: string;
  readonly version: string;
  readonly priority: number;
  readonly condition: Condition;
  readonly actions: readonly RuleAction[];
}

export interface EnginePolicy {
  readonly version: string;
  readonly maxAstDepth: number;
  readonly maxAstNodes: number;
  readonly maxQuestions: number;
  readonly maxRules: number;
  readonly maxActions: number;
  readonly maxStringLength: number;
  readonly maxRegexLength: number;
  readonly maxRegexCost: number;
  readonly maxOperations: number;
  readonly maxInputBytes: number;
  readonly maxDurationMs: number;
  readonly minimumScore: string;
  readonly maximumScore: string;
}

export interface QuestionnaireSnapshot {
  readonly releaseId: string;
  readonly questionnaireVersion: string;
  readonly engineVersion: string;
  readonly questions: readonly QuestionDefinition[];
  readonly rules: readonly RuleDefinition[];
  readonly allowedActionTargets: readonly string[];
  readonly policy: EnginePolicy;
}

export interface PrefillValue {
  readonly value: AnswerValue;
  readonly source: string;
  readonly version: string;
  readonly freshUntil: string;
  readonly authorized: boolean;
}

export interface EvaluationInput {
  readonly correlationId?: string;
  readonly evaluatedAt: string;
  readonly answers: Readonly<Record<string, AnswerValue>>;
  readonly previousAnswers?: Readonly<Record<string, AnswerValue>>;
  readonly prefills?: Readonly<Record<string, PrefillValue>>;
  readonly authorizedContext?: Readonly<Record<string, JsonValue>>;
}

export interface CompiledRule extends RuleDefinition {
  readonly dependencies: readonly string[];
}

export interface CompiledQuestionnaire extends Omit<QuestionnaireSnapshot, "rules"> {
  readonly rules: readonly CompiledRule[];
  readonly snapshotHash: string;
}

export interface RuleTrace {
  readonly ruleKey: string;
  readonly outcome: Truth;
  readonly operations: number;
  readonly explanation: string;
}

export interface AppliedAction extends RuleAction {
  readonly ruleKey: string;
  readonly rulePriority: number;
  readonly actionIndex: number;
  readonly categoryPriority: number;
}

export interface EvaluationResult {
  readonly inputHash: string;
  readonly snapshotHash: string;
  readonly visibleQuestions: readonly string[];
  readonly requiredQuestions: readonly string[];
  readonly prefilledQuestions: readonly string[];
  readonly prefillTrace: readonly Readonly<{ questionKey: string; source: string; version: string; freshUntil: string }>[];
  readonly missingQuestions: readonly string[];
  readonly errors: readonly Readonly<{ questionKey: string; code: string }>[];
  readonly completeness: Readonly<{ answered: number; required: number; basisPoints: number }>;
  readonly score: string;
  readonly scores: Readonly<Record<string, string>>;
  readonly actions: readonly AppliedAction[];
  readonly anomalies: readonly string[];
  readonly rfqBlocked: boolean;
  readonly publicationBlocked: boolean;
  readonly trace: readonly RuleTrace[];
  readonly coercions: readonly Readonly<{ questionKey: string; coercion: Coercion }>[];
}
