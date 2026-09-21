import { z } from "zod";

export const uuidSchema = z.string().uuid();
const versionTextSchema = z.string().trim().min(1).max(80);
const hashSchema = z.string().regex(/^[0-9a-f]{64}$/u);

export const questionnaireVersionRowSchema = z.object({
  id: uuidSchema,
  version: z.number().int().positive(),
  status: z.enum(["DRAFT", "LOCAL_TEST", "FRANCHISE_REVIEW", "CENTRAL_REVIEW", "APPROVED", "SCHEDULED", "PUBLISHED", "SUPERSEDED", "ARCHIVED"]),
  title_fr: z.string().trim().min(2).max(240),
  title_ar: z.string().trim().min(2).max(240),
  audience: z.enum(["CLIENT", "PROVIDER", "FRANCHISE", "INTERNAL"]),
  engine_version: versionTextSchema,
  policy_version: versionTextSchema,
  library_id: uuidSchema,
  catalog_libraries: z.union([
    z.object({ code: z.string().trim().min(2).max(80) }).strict(),
    z.array(z.object({ code: z.string().trim().min(2).max(80) }).strict()).length(1),
  ]),
}).strict();

export const questionnaireQuestionRowSchema = z.object({
  questionnaire_version_id: uuidSchema,
  sort_order: z.number().int().positive(),
  required_override: z.boolean().nullable(),
  question_versions: z.union([
    z.object({
      id: uuidSchema,
      label_fr: z.string().trim().min(1).max(1_000),
      label_ar: z.string().trim().min(1).max(1_000),
      answer_type: z.string().trim().min(2).max(80),
      data_key: z.string().trim().min(2).max(160),
      required_by_default: z.boolean(),
    }).strict(),
    z.array(z.object({
      id: uuidSchema,
      label_fr: z.string().trim().min(1).max(1_000),
      label_ar: z.string().trim().min(1).max(1_000),
      answer_type: z.string().trim().min(2).max(80),
      data_key: z.string().trim().min(2).max(160),
      required_by_default: z.boolean(),
    }).strict()).length(1),
  ]),
}).strict();

export const ruleValidationSchema = z.object({
  valid: z.boolean(),
  questionnaire_version_id: uuidSchema,
  engine_version: versionTextSchema,
  policy_version: versionTextSchema,
  question_count: z.number().int().min(0).max(500),
  rule_count: z.number().int().min(0).max(10_000),
  errors: z.array(z.object({
    rule_version_id: uuidSchema,
    code: z.enum(["RULE_AST_MALFORMED", "RULE_GROUP_MALFORMED", "RULE_DEAD_BRANCH", "RULE_PREDICATE_MALFORMED", "RULE_REFERENCE_OR_OPERATOR_INVALID", "RULE_OPERAND_INVALID", "RULE_REGEX_UNSAFE", "RULE_DEPENDENCY_GRAPH_MALFORMED", "RULE_DEPENDENCY_REFERENCE_INVALID", "RULE_DEPENDENCY_CYCLE", "RULE_ACTIONS_MALFORMED", "RULE_ACTION_MALFORMED", "RULE_ACTION_TYPE_INVALID", "RULE_ACTION_TARGET_INVALID", "RULE_SCORE_ACTION_INVALID", "RULE_VALIDITY_ACTION_INVALID"]),
  }).strict()).max(10_000),
}).strict();

export const ruleActionTypeSchema = z.enum([
  "SHOW", "HIDE", "REQUIRED", "OPTIONAL", "SCORE", "ANOMALY", "RISK", "RECOMMENDATION", "OPPORTUNITY", "SOLUTION_LEVEL", "REQUIRE_DOCUMENT", "HUMAN_REVIEW", "BLOCK_PUBLICATION", "BLOCK_RFQ", "SUGGEST_SERVICE", "START_CHILD_DIAGNOSTIC", "SET_VALIDITY_DAYS",
]);

export const ruleSimulationSchema = z.object({
  questionnaire_version_id: uuidSchema,
  engine_version: versionTextSchema,
  policy_version: versionTextSchema,
  score_basis_points: z.number().int().min(0).max(10_000),
  triggered_actions: z.array(z.object({
    type: ruleActionTypeSchema,
    rule_version_id: uuidSchema,
    evaluation_order: z.number().int().positive(),
  }).passthrough()).max(10_000),
  simulation: z.literal(true),
  reproducibility_hash: hashSchema,
}).strict();

const answerMapSchema = z.record(uuidSchema, z.unknown()).refine((value) => Object.keys(value).length <= 500);

export function parseAnswerMap(raw: string): Record<string, unknown> | null {
  if (new TextEncoder().encode(raw).byteLength > 262_144) return null;
  try {
    const parsed: unknown = JSON.parse(raw);
    const validated = answerMapSchema.safeParse(parsed);
    return validated.success ? validated.data : null;
  } catch {
    return null;
  }
}

export const simulationInputSchema = z.object({
  questionnaireVersionId: uuidSchema,
  answers: answerMapSchema,
  previousAnswers: answerMapSchema,
}).strict();

export type RuleValidationReport = z.infer<typeof ruleValidationSchema>;
export type RuleSimulation = z.infer<typeof ruleSimulationSchema>;
export type RuleValidationWorkspace = {
  versions: Array<{
    id: string;
    version: number;
    status: z.infer<typeof questionnaireVersionRowSchema>["status"];
    titleFr: string;
    titleAr: string;
    audience: z.infer<typeof questionnaireVersionRowSchema>["audience"];
    engineVersion: string;
    policyVersion: string;
    libraryId: string;
    libraryCode: string;
  }>;
  selectedVersionId: string | null;
  questions: Array<{
    id: string;
    sortOrder: number;
    labelFr: string;
    labelAr: string;
    answerType: string;
    dataKey: string;
    required: boolean;
  }>;
};
