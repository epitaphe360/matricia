import { canonicalHash, canonicalize, compareCodePoints } from "./canonical";
import { compareDecimal, normalizeDecimal } from "./decimal";
import { QuestionEngineError } from "./errors";
import type {
  ActionType, CompiledQuestionnaire, Condition, EnginePolicy, QuestionDefinition, QuestionnaireSnapshot,
  RuleAction, RuleDefinition, StructuredFieldDefinition,
} from "./types";

const KEY = /^[A-Z][A-Z0-9_:-]{0,127}$/;
const UTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/;
const QUESTION_TYPES = new Set([
  "YES_NO", "SINGLE_CHOICE", "MULTIPLE_CHOICE", "SHORT_TEXT", "LONG_TEXT", "INTEGER", "DECIMAL", "PERCENTAGE", "MONEY", "CURRENCY",
  "DATE", "DATE_RANGE", "TIME", "EMAIL", "PHONE", "URL", "ADDRESS", "GEO_AREA", "RATING_5", "RATING_10", "QUANTITY", "UNIT_VALUE",
  "FILE", "MULTI_FILE", "IMAGE", "TABLE", "REPEATER", "CONTACT", "ORGANIZATION", "PRODUCT_LIST", "SITE_LIST", "MILESTONE_LIST", "BUDGET_BREAKDOWN",
]);
const QUESTION_ACTIONS = new Set<ActionType>(["REQUIRE_QUESTION", "OPTIONAL_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION", "ADD_VALIDATION_ERROR", "ADD_SCORE", "SET_ANSWER_VALIDITY"]);
const SECTION_ACTIONS = new Set<ActionType>(["SHOW_SECTION", "HIDE_SECTION"]);
const EXTERNAL_TARGET_ACTIONS = new Set<ActionType>(["CREATE_ANOMALY", "CREATE_RISK", "CREATE_RECOMMENDATION", "CREATE_OPPORTUNITY", "ASSOCIATE_SOLUTION_LEVEL", "REQUEST_DOCUMENT", "SUGGEST_SERVICE", "START_CHILD_DIAGNOSTIC"]);
const DEPENDENCY_ACTIONS = new Set<ActionType>(["REQUIRE_QUESTION", "OPTIONAL_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION"]);
const ACTIONS = new Set<ActionType>([
  "BLOCK_PUBLICATION", "BLOCK_RFQ", "REQUIRE_QUESTION", "OPTIONAL_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION",
  "SHOW_SECTION", "HIDE_SECTION", "ADD_VALIDATION_ERROR", "ADD_SCORE", "CREATE_ANOMALY", "CREATE_RISK",
  "CREATE_RECOMMENDATION", "CREATE_OPPORTUNITY", "ASSOCIATE_SOLUTION_LEVEL", "REQUEST_DOCUMENT",
  "REQUIRE_HUMAN_REVIEW", "SUGGEST_SERVICE", "START_CHILD_DIAGNOSTIC", "SET_ANSWER_VALIDITY",
]);
const PREDICATES = new Set(["EQ", "NE", "GT", "LT", "IN", "CONTAINS", "IS_EMPTY", "IS_NOT_EMPTY", "REGEX", "DATE_BEFORE", "DATE_AFTER", "CHANGED", "IS_UNKNOWN"]);
const OPPOSITES: Readonly<Record<string, string>> = Object.freeze({
  REQUIRE_QUESTION: "OPTIONAL_QUESTION", OPTIONAL_QUESTION: "REQUIRE_QUESTION",
  SHOW_QUESTION: "HIDE_QUESTION", HIDE_QUESTION: "SHOW_QUESTION",
  SHOW_SECTION: "HIDE_SECTION", HIDE_SECTION: "SHOW_SECTION",
});

function positiveInteger(value: number): boolean {
  return Number.isSafeInteger(value) && value > 0;
}

function validatePolicy(policy: EnginePolicy): void {
  const values = [policy.maxAstDepth, policy.maxAstNodes, policy.maxQuestions, policy.maxRules, policy.maxActions, policy.maxStringLength,
    policy.maxRegexLength, policy.maxRegexCost, policy.maxOperations, policy.maxInputBytes, policy.maxDurationMs];
  if (!policy.version || values.some((value) => !positiveInteger(value))) throw new QuestionEngineError("INVALID_SNAPSHOT");
  normalizeDecimal(policy.minimumScore);
  normalizeDecimal(policy.maximumScore);
  if (compareDecimal(policy.minimumScore, policy.maximumScore) > 0) throw new QuestionEngineError("INVALID_SNAPSHOT");
}

function boundedString(value: unknown, policy: EnginePolicy): value is string {
  return typeof value === "string" && value.length > 0 && value.length <= policy.maxStringLength;
}

function validateControlledRegex(pattern: string, policy: EnginePolicy): void {
  if (pattern.length === 0 || pattern.length > policy.maxRegexLength) throw new QuestionEngineError("INVALID_REGEX");
  // Native RegExp has no execution timeout. Accept a deliberately small linear-time subset:
  // full anchoring, no backreferences/lookarounds, quantified groups, open repetitions, or multiple unbounded quantifiers.
  const unbounded = pattern.match(/(?<!\\)[*+]/g)?.length ?? 0;
  const repetitions = [...pattern.matchAll(/\{(\d+)(?:,(\d+))?\}/g)];
  if (!pattern.startsWith("^") || !pattern.endsWith("$") || /(?<!\\)\||\\[1-9]|\(\?[:=!<]|\(\?<|\{\d+,\}|(?:\*|\+|\?){2}|\)[+*{]|\([^)]*[+*][^)]*\)[+*]/.test(pattern)
      || unbounded > 1 || repetitions.some((match) => Number(match[2] ?? match[1]) > 100)) {
    throw new QuestionEngineError("INVALID_REGEX");
  }
  const cost = pattern.length + (pattern.match(/[|*+?{[]/g)?.length ?? 0) * 8;
  if (cost > policy.maxRegexCost) throw new QuestionEngineError("INVALID_REGEX");
  try { new RegExp(pattern, "u"); } catch { throw new QuestionEngineError("INVALID_REGEX"); }
}

function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value;
}

function rejectProvableDeadBranch(condition: Extract<Condition, { kind: "GROUP" }>): void {
  if (condition.operator !== "AND") return;
  const equals = new Map<string, string>();
  const positive = new Set<string>();
  const negative = new Set<string>();
  for (const child of condition.children) {
    const signature = canonicalize(child);
    if (child.kind === "NOT") negative.add(canonicalize(child.child));
    else positive.add(signature);
    if (child.kind === "PREDICATE" && child.operator === "EQ") {
      const operand = canonicalize(child.operand);
      const current = equals.get(child.questionKey);
      if (current !== undefined && current !== operand) throw new QuestionEngineError("INVALID_AST");
      equals.set(child.questionKey, operand);
    }
  }
  if ([...positive].some((signature) => negative.has(signature))) throw new QuestionEngineError("INVALID_AST");
}

function record(value: unknown): Readonly<Record<string, unknown>> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? value as Readonly<Record<string, unknown>> : undefined;
}

function isSnapshotRoot(value: unknown): value is QuestionnaireSnapshot {
  const root = record(value);
  return root !== undefined
    && record(root.policy) !== undefined
    && Array.isArray(root.questions)
    && Array.isArray(root.rules)
    && Array.isArray(root.allowedActionTargets);
}

function assertAcyclicSnapshot(value: unknown, ancestors = new WeakSet<object>()): void {
  if (value === null || typeof value !== "object") return;
  if (ancestors.has(value)) throw new QuestionEngineError("INVALID_SNAPSHOT");
  ancestors.add(value);
  for (const child of Object.values(value)) assertAcyclicSnapshot(child, ancestors);
  ancestors.delete(value);
}

function operandMatches(question: QuestionDefinition, operand: unknown): boolean {
  if (operand === null) return question.nullable;
  if (question.type === "YES_NO") return typeof operand === "boolean";
  if (["INTEGER", "RATING_5", "RATING_10"].includes(question.type)) {
    const item = record(operand);
    return item?.kind === "INTEGER" && typeof item.value === "string" && /^-?(?:0|[1-9]\d*)$/.test(item.value);
  }
  if (["DECIMAL", "PERCENTAGE", "QUANTITY", "UNIT_VALUE"].includes(question.type)) {
    const item = record(operand);
    if (item?.kind !== "DECIMAL" || typeof item.value !== "string") return false;
    try { return normalizeDecimal(item.value) === item.value; } catch { return false; }
  }
  if (question.type === "MONEY") {
    const item = record(operand);
    return item?.kind === "MONEY" && typeof item.amountMinor === "string" && /^-?(?:0|[1-9]\d*)$/.test(item.amountMinor) && typeof item.currency === "string" && /^[A-Z]{3}$/.test(item.currency);
  }
  if (question.type === "DATE_RANGE") {
    const item = record(operand);
    return item?.kind === "DATE_RANGE" && typeof item.start === "string" && typeof item.end === "string" && validDate(item.start) && validDate(item.end) && item.start <= item.end;
  }
  if (question.type === "TIME") {
    const item = record(operand);
    return item?.kind === "LOCAL_TIME" && typeof item.localDate === "string" && validDate(item.localDate)
      && typeof item.localTime === "string" && /^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(item.localTime)
      && typeof item.timeZone === "string" && typeof item.dstPolicy === "string" && ["EARLIER", "LATER", "REJECT"].includes(item.dstPolicy);
  }
  if (["MULTIPLE_CHOICE", "MULTI_FILE", "PRODUCT_LIST", "SITE_LIST", "MILESTONE_LIST"].includes(question.type)) return Array.isArray(operand);
  if (["CONTACT", "ORGANIZATION", "BUDGET_BREAKDOWN"].includes(question.type)) return record(operand) !== undefined;
  if (question.type === "DATE") return typeof operand === "string" && validDate(operand);
  return typeof operand === "string";
}

function structuredItemMatches(question: QuestionDefinition, operand: unknown): boolean {
  const item = record(operand);
  const schema = question.structured;
  if (!item || !schema) return false;
  const fields = schema.kind === "TABLE" ? schema.columns : schema.children;
  if (Object.keys(item).length !== fields.length || fields.some((field) => !Object.prototype.hasOwnProperty.call(item, field.key))) return false;
  return fields.every((field) => {
    const value = item[field.key];
    if (value === null) return field.nullable;
    const synthetic: QuestionDefinition = {
      key: field.key, sectionKey: question.sectionKey, version: "1", type: field.type, nullable: field.nullable,
      visibleByDefault: true, requiredByDefault: false, requiredForQuote: false, requiredForPublication: false,
      ...(field.options ? { options: field.options } : {}), ...(field.numeric ? { numeric: field.numeric } : {}),
      ...(field.validation ? { validation: field.validation } : {}),
    };
    const selected = Array.isArray(value) ? value : [value];
    return operandMatches(synthetic, value) && (!field.options || selected.every((entry) => typeof entry === "string" && field.options?.includes(entry)));
  });
}

function validateStructuredField(field: StructuredFieldDefinition, policy: EnginePolicy): void {
  const allowed = new Set(["key", "type", "nullable", "options", "numeric", "validation"]);
  if (Object.keys(field).some((key) => !allowed.has(key)) || !KEY.test(field.key)) throw new QuestionEngineError("INVALID_SNAPSHOT");
  const synthetic: QuestionDefinition = {
    key: field.key, sectionKey: "STRUCTURED", version: "1", type: field.type, nullable: field.nullable,
    visibleByDefault: true, requiredByDefault: false, requiredForQuote: false, requiredForPublication: false,
    ...(field.options ? { options: field.options } : {}), ...(field.numeric ? { numeric: field.numeric } : {}),
    ...(field.validation ? { validation: field.validation } : {}),
  };
  validateQuestion(synthetic, policy, true);
}

function validateQuestion(question: QuestionDefinition, policy: EnginePolicy, nested = false): void {
  if (!KEY.test(question.key) || !KEY.test(question.sectionKey) || !boundedString(question.version, policy) || !QUESTION_TYPES.has(question.type)) throw new QuestionEngineError("INVALID_SNAPSHOT");
  if (question.options && (question.options.length === 0 || new Set(question.options).size !== question.options.length || question.options.some((item) => !boundedString(item, policy)))) {
    throw new QuestionEngineError("INVALID_SNAPSHOT");
  }
  if (question.options && !["SINGLE_CHOICE", "MULTIPLE_CHOICE"].includes(question.type)) throw new QuestionEngineError("INVALID_SNAPSHOT");
  if (question.coercion) {
    const accepted = (question.coercion === "STRING_TO_INTEGER" && question.type === "INTEGER")
      || (question.coercion === "STRING_TO_DECIMAL" && ["DECIMAL", "PERCENTAGE", "QUANTITY", "UNIT_VALUE"].includes(question.type))
      || (question.coercion === "STRING_TO_BOOLEAN" && question.type === "YES_NO")
      || (question.coercion === "STRING_TO_DATE" && question.type === "DATE");
    if (!accepted) throw new QuestionEngineError("INVALID_SNAPSHOT");
  }
  const validation = question.validation;
  if (validation) {
    for (const limit of [validation.minLength, validation.maxLength, validation.minItems, validation.maxItems]) {
      if (limit !== undefined && (!Number.isSafeInteger(limit) || limit < 0)) throw new QuestionEngineError("INVALID_SNAPSHOT");
    }
    if (validation.minLength !== undefined && validation.maxLength !== undefined && validation.minLength > validation.maxLength) throw new QuestionEngineError("INVALID_SNAPSHOT");
    if (validation.minItems !== undefined && validation.maxItems !== undefined && validation.minItems > validation.maxItems) throw new QuestionEngineError("INVALID_SNAPSHOT");
    if (validation.minimum !== undefined) normalizeDecimal(validation.minimum);
    if (validation.maximum !== undefined) normalizeDecimal(validation.maximum);
    if (validation.minimum !== undefined && validation.maximum !== undefined && compareDecimal(validation.minimum, validation.maximum) > 0) throw new QuestionEngineError("INVALID_SNAPSHOT");
    if (validation.pattern !== undefined) {
      if (!["SHORT_TEXT", "LONG_TEXT", "EMAIL", "PHONE", "URL"].includes(question.type)) throw new QuestionEngineError("INVALID_SNAPSHOT");
      validateControlledRegex(validation.pattern, policy);
    }
  }
  if (question.scoreMaximum !== undefined) normalizeDecimal(question.scoreMaximum);
  const numericTypes = ["INTEGER", "DECIMAL", "PERCENTAGE", "QUANTITY", "UNIT_VALUE", "RATING_5", "RATING_10"];
  if (numericTypes.includes(question.type)) {
    if (!question.numeric || !["HALF_UP", "HALF_EVEN", "DOWN", "UP"].includes(question.numeric.rounding)
        || !Number.isSafeInteger(question.numeric.precision) || question.numeric.precision < 1 || question.numeric.precision > 1_000
        || !Number.isSafeInteger(question.numeric.scale) || question.numeric.scale < 0 || question.numeric.scale > question.numeric.precision) throw new QuestionEngineError("INVALID_SNAPSHOT");
    if (["INTEGER", "RATING_5", "RATING_10"].includes(question.type) && question.numeric.scale !== 0) throw new QuestionEngineError("INVALID_SNAPSHOT");
  }
  if (!numericTypes.includes(question.type) && question.numeric) throw new QuestionEngineError("INVALID_SNAPSHOT");
  if (question.type === "TABLE" || question.type === "REPEATER") {
    const schema = question.structured;
    if (!schema || schema.kind !== question.type || !boundedString(schema.version, policy)) throw new QuestionEngineError("INVALID_SNAPSHOT");
    const isTable = schema.kind === "TABLE";
    const allowed = new Set(isTable ? ["version", "kind", "minRows", "maxRows", "columns"] : ["version", "kind", "minItems", "maxItems", "children"]);
    if (Object.keys(schema).some((key) => !allowed.has(key))) throw new QuestionEngineError("INVALID_SNAPSHOT");
    const minimum = isTable ? schema.minRows : schema.minItems;
    const maximum = isTable ? schema.maxRows : schema.maxItems;
    const fields = isTable ? schema.columns : schema.children;
    if (!Number.isSafeInteger(minimum) || minimum < 0 || !positiveInteger(maximum) || minimum > maximum || maximum > policy.maxQuestions
        || fields.length === 0 || fields.length > policy.maxQuestions || new Set(fields.map((field) => field.key)).size !== fields.length) throw new QuestionEngineError("INVALID_SNAPSHOT");
    for (const field of fields) validateStructuredField(field, policy);
  } else if (question.structured) throw new QuestionEngineError("INVALID_SNAPSHOT");
  if (nested && ["TABLE", "REPEATER"].includes(question.type)) throw new QuestionEngineError("INVALID_SNAPSHOT");
}

interface WalkState { nodes: number; dependencies: Set<string> }

function walkCondition(condition: Condition, depth: number, state: WalkState, questions: ReadonlyMap<string, QuestionDefinition>, policy: EnginePolicy): void {
  state.nodes += 1;
  if (state.nodes > policy.maxAstNodes || depth > policy.maxAstDepth) throw new QuestionEngineError("INVALID_AST");
  if (condition.kind === "GROUP") {
    if ((condition.operator !== "AND" && condition.operator !== "OR") || condition.children.length === 0) throw new QuestionEngineError("INVALID_AST");
    rejectProvableDeadBranch(condition);
    for (const child of condition.children) walkCondition(child, depth + 1, state, questions, policy);
    return;
  }
  if (condition.kind === "NOT") {
    walkCondition(condition.child, depth + 1, state, questions, policy);
    return;
  }
  if (condition.kind !== "PREDICATE" || !PREDICATES.has(condition.operator)) throw new QuestionEngineError("INVALID_AST");
  const question = questions.get(condition.questionKey);
  if (!question) throw new QuestionEngineError("INVALID_REFERENCE");
  state.dependencies.add(condition.questionKey);
  const unary = condition.operator === "IS_EMPTY" || condition.operator === "IS_NOT_EMPTY" || condition.operator === "CHANGED" || condition.operator === "IS_UNKNOWN";
  if (unary === (condition.operand !== undefined)) throw new QuestionEngineError("INVALID_AST");
  if (condition.operator === "REGEX") {
    if (typeof condition.operand !== "string" || !["SHORT_TEXT", "LONG_TEXT", "EMAIL", "PHONE", "URL"].includes(question.type)) throw new QuestionEngineError("INVALID_TYPE");
    validateControlledRegex(condition.operand, policy);
  }
  if ((condition.operator === "DATE_BEFORE" || condition.operator === "DATE_AFTER") && (question.type !== "DATE" || typeof condition.operand !== "string" || !validDate(condition.operand))) throw new QuestionEngineError("INVALID_TYPE");
  if (condition.operator === "GT" || condition.operator === "LT") {
    if (!["INTEGER", "DECIMAL", "PERCENTAGE", "QUANTITY", "UNIT_VALUE", "RATING_5", "RATING_10"].includes(question.type) || !operandMatches(question, condition.operand)) throw new QuestionEngineError("INVALID_TYPE");
  }
  if ((condition.operator === "EQ" || condition.operator === "NE") && !operandMatches(question, condition.operand)) throw new QuestionEngineError("INVALID_TYPE");
  if (condition.operator === "IN") {
    const collections = ["MULTIPLE_CHOICE", "MULTI_FILE", "PRODUCT_LIST", "SITE_LIST", "MILESTONE_LIST", "TABLE", "REPEATER"];
    if (collections.includes(question.type) || !Array.isArray(condition.operand) || condition.operand.length === 0
        || condition.operand.some((item) => !operandMatches(question, item))
        || (question.type === "SINGLE_CHOICE" && condition.operand.some((item) => typeof item !== "string" || !question.options?.includes(item)))) {
      throw new QuestionEngineError("INVALID_TYPE");
    }
  }
  if (condition.operator === "CONTAINS") {
    const text = ["SHORT_TEXT", "LONG_TEXT", "EMAIL", "PHONE", "URL"].includes(question.type);
    const choice = question.type === "MULTIPLE_CHOICE";
    const files = question.type === "MULTI_FILE";
    const structuredObjects = ["TABLE", "REPEATER"].includes(question.type);
    const objects = ["PRODUCT_LIST", "SITE_LIST", "MILESTONE_LIST"].includes(question.type);
    if ((text && typeof condition.operand !== "string")
        || (choice && (typeof condition.operand !== "string" || !question.options?.includes(condition.operand)))
        || (files && typeof condition.operand !== "string") || (objects && record(condition.operand) === undefined)
        || (structuredObjects && !structuredItemMatches(question, condition.operand))
        || (!text && !choice && !files && !objects && !structuredObjects)) throw new QuestionEngineError("INVALID_TYPE");
  }
  if (condition.operand !== undefined && canonicalize(condition.operand).length > policy.maxStringLength * 2) throw new QuestionEngineError("INVALID_AST");
}

function validateActions(rule: RuleDefinition, questions: ReadonlyMap<string, QuestionDefinition>, allowedTargets: ReadonlySet<string>, policy: EnginePolicy): void {
  if (rule.actions.length === 0 || rule.actions.length > policy.maxActions) throw new QuestionEngineError("INVALID_AST");
  const signatures = new Set<string>();
  for (const action of rule.actions) {
    if (!ACTIONS.has(action.type)) throw new QuestionEngineError("INVALID_AST");
    if (action.target !== undefined && !boundedString(action.target, policy)) throw new QuestionEngineError("INVALID_AST");
    if (action.value !== undefined && !boundedString(action.value, policy)) throw new QuestionEngineError("INVALID_AST");
    if (action.messageKey !== undefined && !boundedString(action.messageKey, policy)) throw new QuestionEngineError("INVALID_AST");
    if (QUESTION_ACTIONS.has(action.type) && (!action.target || !questions.has(action.target))) throw new QuestionEngineError("INVALID_REFERENCE");
    if (SECTION_ACTIONS.has(action.type) && (!action.target || !new Set([...questions.values()].map((question) => question.sectionKey)).has(action.target))) throw new QuestionEngineError("INVALID_REFERENCE");
    if (EXTERNAL_TARGET_ACTIONS.has(action.type) && (!action.target || !allowedTargets.has(action.target))) throw new QuestionEngineError("INVALID_REFERENCE");
    if (action.type === "ADD_SCORE") {
      if (action.value === undefined) throw new QuestionEngineError("INVALID_TYPE");
      const score = normalizeDecimal(action.value);
      if (compareDecimal(score, policy.minimumScore) < 0 || compareDecimal(score, policy.maximumScore) > 0) throw new QuestionEngineError("INVALID_TYPE");
      const maximum = action.target ? questions.get(action.target)?.scoreMaximum : undefined;
      if (maximum !== undefined && compareDecimal(score, maximum) > 0) throw new QuestionEngineError("INVALID_TYPE");
    }
    const target = action.target ?? "__GLOBAL__";
    if (signatures.has(`${OPPOSITES[action.type]}:${target}`)) throw new QuestionEngineError("ACTION_CONFLICT");
    signatures.add(`${action.type}:${target}`);
  }
}

function detectCycles(rules: readonly { definition: RuleDefinition; dependencies: Set<string> }[]): void {
  const graph = new Map<string, Set<string>>();
  for (const { definition, dependencies } of rules) {
    for (const action of definition.actions) {
      if (!DEPENDENCY_ACTIONS.has(action.type) || !action.target) continue;
      if (!graph.has(action.target)) graph.set(action.target, new Set());
      for (const source of dependencies) {
        if (source === action.target) throw new QuestionEngineError("RULE_CYCLE");
        if (!graph.has(source)) graph.set(source, new Set());
        graph.get(source)?.add(action.target);
      }
    }
  }
  const visiting = new Set<string>();
  const visited = new Set<string>();
  const visit = (node: string): void => {
    if (visiting.has(node)) throw new QuestionEngineError("RULE_CYCLE");
    if (visited.has(node)) return;
    visiting.add(node);
    for (const next of graph.get(node) ?? []) visit(next);
    visiting.delete(node);
    visited.add(node);
  };
  for (const node of graph.keys()) visit(node);
}

function compileQuestionnaireInternal(snapshot: QuestionnaireSnapshot): CompiledQuestionnaire {
  let safeSnapshot: QuestionnaireSnapshot;
  try { safeSnapshot = structuredClone(snapshot); } catch { throw new QuestionEngineError("INVALID_SNAPSHOT"); }
  safeSnapshot = {
    ...safeSnapshot,
    policy: { ...safeSnapshot.policy, minimumScore: normalizeDecimal(safeSnapshot.policy.minimumScore), maximumScore: normalizeDecimal(safeSnapshot.policy.maximumScore) },
    questions: safeSnapshot.questions.map((question) => ({
      ...question,
      ...(question.scoreMaximum === undefined ? {} : { scoreMaximum: normalizeDecimal(question.scoreMaximum) }),
      ...(question.validation === undefined ? {} : { validation: {
        ...question.validation,
        ...(question.validation.minimum === undefined ? {} : { minimum: normalizeDecimal(question.validation.minimum) }),
        ...(question.validation.maximum === undefined ? {} : { maximum: normalizeDecimal(question.validation.maximum) }),
      } }),
      ...(question.structured === undefined ? {} : { structured: question.structured.kind === "TABLE" ? {
        ...question.structured,
        columns: question.structured.columns.map((field) => ({ ...field, ...(field.validation === undefined ? {} : { validation: {
          ...field.validation,
          ...(field.validation.minimum === undefined ? {} : { minimum: normalizeDecimal(field.validation.minimum) }),
          ...(field.validation.maximum === undefined ? {} : { maximum: normalizeDecimal(field.validation.maximum) }),
        } }) })),
      } : {
        ...question.structured,
        children: question.structured.children.map((field) => ({ ...field, ...(field.validation === undefined ? {} : { validation: {
          ...field.validation,
          ...(field.validation.minimum === undefined ? {} : { minimum: normalizeDecimal(field.validation.minimum) }),
          ...(field.validation.maximum === undefined ? {} : { maximum: normalizeDecimal(field.validation.maximum) }),
        } }) })),
      } }),
    })),
    rules: safeSnapshot.rules.map((rule) => ({ ...rule, actions: rule.actions.map((action) => action.type === "ADD_SCORE" && action.value !== undefined ? { ...action, value: normalizeDecimal(action.value) } : action) })),
  };
  validatePolicy(safeSnapshot.policy);
  if (!boundedString(safeSnapshot.releaseId, safeSnapshot.policy) || !boundedString(safeSnapshot.questionnaireVersion, safeSnapshot.policy) || !boundedString(safeSnapshot.engineVersion, safeSnapshot.policy)) throw new QuestionEngineError("INVALID_SNAPSHOT");
  if (safeSnapshot.rules.length > safeSnapshot.policy.maxRules || safeSnapshot.questions.length === 0 || safeSnapshot.questions.length > safeSnapshot.policy.maxQuestions) throw new QuestionEngineError("INVALID_SNAPSHOT");
  const questionMap = new Map<string, QuestionDefinition>();
  if (!Array.isArray(safeSnapshot.allowedActionTargets) || safeSnapshot.allowedActionTargets.some((target) => !KEY.test(target)) || new Set(safeSnapshot.allowedActionTargets).size !== safeSnapshot.allowedActionTargets.length) throw new QuestionEngineError("INVALID_SNAPSHOT");
  const allowedTargets = new Set(safeSnapshot.allowedActionTargets);
  for (const question of safeSnapshot.questions) {
    validateQuestion(question, safeSnapshot.policy);
    if (questionMap.has(question.key)) throw new QuestionEngineError("INVALID_SNAPSHOT");
    questionMap.set(question.key, question);
  }
  const keys = new Set<string>();
  const walked: { definition: RuleDefinition; dependencies: Set<string> }[] = [];
  let actionCount = 0;
  for (const rule of safeSnapshot.rules) {
    if (!KEY.test(rule.key) || keys.has(rule.key) || !boundedString(rule.version, safeSnapshot.policy) || !Number.isSafeInteger(rule.priority)) throw new QuestionEngineError("INVALID_SNAPSHOT");
    keys.add(rule.key);
    const state: WalkState = { nodes: 0, dependencies: new Set() };
    walkCondition(rule.condition, 1, state, questionMap, safeSnapshot.policy);
    actionCount += rule.actions.length;
    if (actionCount > safeSnapshot.policy.maxActions) throw new QuestionEngineError("INVALID_AST");
    validateActions(rule, questionMap, allowedTargets, safeSnapshot.policy);
    walked.push({ definition: rule, dependencies: state.dependencies });
  }
  detectCycles(walked);
  const rules = walked.map(({ definition, dependencies }) => ({ ...definition, dependencies: [...dependencies].sort(compareCodePoints) }));
  const normalized = { ...safeSnapshot, allowedActionTargets: [...safeSnapshot.allowedActionTargets].sort(compareCodePoints), questions: [...safeSnapshot.questions].sort((a, b) => compareCodePoints(a.key, b.key)), rules: [...rules].sort((a, b) => compareCodePoints(a.key, b.key)) };
  return deepFreeze({ ...normalized, snapshotHash: canonicalHash(normalized) });
}

export function compileQuestionnaire(snapshot: QuestionnaireSnapshot): CompiledQuestionnaire {
  try {
    if (!isSnapshotRoot(snapshot)) throw new QuestionEngineError("INVALID_SNAPSHOT");
    assertAcyclicSnapshot(snapshot);
    return compileQuestionnaireInternal(snapshot);
  } catch (error) {
    if (error instanceof QuestionEngineError) {
      if (error.code === "INVALID_INPUT") throw new QuestionEngineError("INVALID_SNAPSHOT");
      throw error;
    }
    throw new QuestionEngineError("INVALID_SNAPSHOT");
  }
}

function deepFreeze<T>(value: T): T {
  if (typeof value !== "object" || value === null || Object.isFrozen(value)) return value;
  for (const child of Object.values(value)) deepFreeze(child);
  return Object.freeze(value);
}

export function isUtcInstant(value: string): boolean {
  const match = UTC.exec(value);
  if (!match || !Number.isFinite(Date.parse(value))) return false;
  const [date, time = ""] = value.split("T");
  if (!date || !/^\d{2}:\d{2}:\d{2}/.test(time)) return false;
  const [hour = 99, minute = 99, second = 99] = time.slice(0, 8).split(":").map(Number);
  const parsedDate = new Date(`${date}T00:00:00.000Z`);
  return parsedDate.toISOString().slice(0, 10) === date && hour <= 23 && minute <= 59 && second <= 59;
}
