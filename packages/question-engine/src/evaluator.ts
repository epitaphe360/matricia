import { performance } from "node:perf_hooks";
import { canonicalHash, canonicalize, compareCodePoints } from "./canonical";
import { addDecimal, compareDecimal, exactInteger, normalizeDecimal, roundDecimal } from "./decimal";
import { QuestionEngineError } from "./errors";
import { isUtcInstant } from "./compiler";
import { UNKNOWN, type AnswerValue, type AppliedAction, type Coercion, type CompiledQuestionnaire, type Condition, type EvaluationInput, type EvaluationResult, type QuestionDefinition, type RuleAction, type RuleTrace, type Truth } from "./types";

interface Runtime { operations: number; readonly started: number; readonly questionnaire: CompiledQuestionnaire }

function tick(runtime: Runtime, count = 1): void {
  runtime.operations += count;
  if (runtime.operations > runtime.questionnaire.policy.maxOperations || performance.now() - runtime.started > runtime.questionnaire.policy.maxDurationMs) {
    throw new QuestionEngineError("BUDGET_EXCEEDED");
  }
}

function isUnknown(value: AnswerValue | undefined): boolean {
  return value === undefined || (typeof value === "object" && value !== null && "kind" in value && value.kind === "UNKNOWN");
}

function isEmpty(value: AnswerValue): boolean {
  return value === null || value === "" || (Array.isArray(value) && value.length === 0);
}

function dateValid(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value;
}

function decimalShape(value: string): { digits: number; scale: number } | undefined {
  if (!/^-?(?:0|[1-9]\d*)(?:\.\d+)?$/.test(value)) return undefined;
  const unsigned = value.startsWith("-") ? value.slice(1) : value;
  const [integer = "0", fraction = ""] = unsigned.split(".");
  return { digits: integer.replace(/^0+/, "").length + fraction.length || 1, scale: fraction.length };
}

function deepFreeze<T>(value: T): T {
  if (value !== null && typeof value === "object" && !Object.isFrozen(value)) {
    Object.freeze(value);
    for (const child of Object.values(value as Record<string, unknown>)) deepFreeze(child);
  }
  return value;
}

interface LocalParts { year: number; month: number; day: number; hour: number; minute: number; second: number }

function parseLocalParts(localDate: string, localTime: string): LocalParts | undefined {
  if (!dateValid(localDate) || !/^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(localTime)) return undefined;
  const [year, month, day] = localDate.split("-").map(Number);
  const [hour, minute, second = 0] = localTime.split(":").map(Number);
  return { year: year!, month: month!, day: day!, hour: hour!, minute: minute!, second };
}

function partsAt(epochMs: number, timeZone: string): LocalParts {
  const values: Record<string, number> = {};
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
  });
  for (const part of formatter.formatToParts(epochMs)) {
    if (part.type !== "literal") values[part.type] = Number(part.value);
  }
  return { year: values.year!, month: values.month!, day: values.day!, hour: values.hour!, minute: values.minute!, second: values.second! };
}

function sameParts(left: LocalParts, right: LocalParts): boolean {
  return left.year === right.year && left.month === right.month && left.day === right.day && left.hour === right.hour && left.minute === right.minute && left.second === right.second;
}

function utcEpoch(parts: LocalParts): number {
  const date = new Date(0);
  date.setUTCFullYear(parts.year, parts.month - 1, parts.day);
  date.setUTCHours(parts.hour, parts.minute, parts.second, 0);
  return date.valueOf();
}

/** Resolves a wall-clock time without guessing across DST gaps or folds. */
export function resolveLocalTimeEpoch(value: { readonly localDate: string; readonly localTime: string; readonly timeZone: string; readonly dstPolicy: "EARLIER" | "LATER" | "REJECT" }): number | undefined {
  const wanted = parseLocalParts(value.localDate, value.localTime);
  if (!wanted || !isIanaTimeZone(value.timeZone)) return undefined;
  const wallUtc = utcEpoch(wanted);
  const offsets = new Set<number>();
  for (let sample = wallUtc - 36 * 3_600_000; sample <= wallUtc + 36 * 3_600_000; sample += 6 * 3_600_000) {
    const parts = partsAt(sample, value.timeZone);
    offsets.add(utcEpoch(parts) - sample);
  }
  const candidates = [...offsets]
    .map((offset) => wallUtc - offset)
    .filter((candidate) => sameParts(partsAt(candidate, value.timeZone), wanted))
    .filter((candidate, index, all) => all.indexOf(candidate) === index)
    .sort((a, b) => a - b);
  if (candidates.length === 0 || (candidates.length > 1 && value.dstPolicy === "REJECT")) return undefined;
  return value.dstPolicy === "LATER" ? candidates.at(-1) : candidates[0];
}

function exactValue(value: AnswerValue): string | undefined {
  if (typeof value === "object" && value !== null && !Array.isArray(value) && "kind" in value && "value" in value) {
    if ((value.kind === "INTEGER" || value.kind === "DECIMAL") && typeof value.value === "string") return value.value;
  }
  return undefined;
}

function equivalent(left: AnswerValue, right: AnswerValue): boolean {
  return canonicalize(left) === canonicalize(right);
}

function truthNot(value: Truth): Truth { return value === "UNKNOWN" ? value : value === "TRUE" ? "FALSE" : "TRUE"; }

function evaluateCondition(condition: Condition, answers: Readonly<Record<string, AnswerValue>>, previous: Readonly<Record<string, AnswerValue>>, runtime: Runtime): Truth {
  tick(runtime);
  if (condition.kind === "NOT") return truthNot(evaluateCondition(condition.child, answers, previous, runtime));
  if (condition.kind === "GROUP") {
    const results = condition.children.map((child) => evaluateCondition(child, answers, previous, runtime));
    if (condition.operator === "AND") return results.includes("FALSE") ? "FALSE" : results.includes("UNKNOWN") ? "UNKNOWN" : "TRUE";
    return results.includes("TRUE") ? "TRUE" : results.includes("UNKNOWN") ? "UNKNOWN" : "FALSE";
  }
  const current = answers[condition.questionKey];
  if (condition.operator === "IS_UNKNOWN") return isUnknown(current) ? "TRUE" : "FALSE";
  if (isUnknown(current)) return "UNKNOWN";
  const value = current as AnswerValue;
  if (condition.operator === "IS_EMPTY") return isEmpty(value) ? "TRUE" : "FALSE";
  if (condition.operator === "IS_NOT_EMPTY") return isEmpty(value) ? "FALSE" : "TRUE";
  if (condition.operator === "CHANGED") {
    const old = previous[condition.questionKey];
    return isUnknown(old) ? "UNKNOWN" : equivalent(value, old as AnswerValue) ? "FALSE" : "TRUE";
  }
  const operand = condition.operand as AnswerValue;
  if (isUnknown(operand)) return "UNKNOWN";
  if (condition.operator === "EQ" || condition.operator === "NE") {
    const equal = equivalent(value, operand);
    return (condition.operator === "EQ" ? equal : !equal) ? "TRUE" : "FALSE";
  }
  if (condition.operator === "IN") return Array.isArray(operand) && operand.some((item) => equivalent(value, item)) ? "TRUE" : "FALSE";
  if (condition.operator === "CONTAINS") {
    const contains = typeof value === "string" && typeof operand === "string" ? value.includes(operand) : Array.isArray(value) ? value.some((item) => equivalent(item, operand)) : false;
    return contains ? "TRUE" : "FALSE";
  }
  if (condition.operator === "REGEX") return typeof value === "string" && typeof operand === "string" && new RegExp(operand, "u").test(value) ? "TRUE" : "FALSE";
  if (condition.operator === "DATE_BEFORE" || condition.operator === "DATE_AFTER") {
    if (typeof value !== "string" || typeof operand !== "string" || !dateValid(value) || !dateValid(operand)) return "FALSE";
    return (condition.operator === "DATE_BEFORE" ? value < operand : value > operand) ? "TRUE" : "FALSE";
  }
  const leftExact = exactValue(value);
  const rightExact = exactValue(operand);
  if (leftExact === undefined || rightExact === undefined) return "FALSE";
  const comparison = compareDecimal(leftExact, rightExact);
  return (condition.operator === "GT" ? comparison > 0 : comparison < 0) ? "TRUE" : "FALSE";
}

function coerce(question: QuestionDefinition, raw: AnswerValue): { value: AnswerValue; coercion?: Coercion } {
  const exact = exactValue(raw);
  if (exact !== undefined && question.numeric && typeof raw === "object" && raw !== null && !Array.isArray(raw) && "kind" in raw
      && (raw.kind !== "INTEGER" || exactInteger(exact))) {
    return { value: { kind: raw.kind as "INTEGER" | "DECIMAL", value: roundDecimal(exact, question.numeric.scale, question.numeric.rounding) } };
  }
  if (!question.coercion || typeof raw !== "string") return { value: raw };
  try {
    switch (question.coercion) {
      case "STRING_TO_INTEGER":
        if (!exactInteger(raw)) throw new Error();
        return { value: { kind: "INTEGER", value: raw }, coercion: question.coercion };
      case "STRING_TO_DECIMAL":
        return { value: { kind: "DECIMAL", value: roundDecimal(raw, question.numeric?.scale ?? 0, question.numeric?.rounding ?? "HALF_EVEN") }, coercion: question.coercion };
      case "STRING_TO_BOOLEAN":
        if (raw !== "true" && raw !== "false") throw new Error();
        return { value: raw === "true", coercion: question.coercion };
      case "STRING_TO_DATE":
        if (!dateValid(raw)) throw new Error();
        return { value: raw, coercion: question.coercion };
    }
  } catch { throw new QuestionEngineError("INVALID_TYPE"); }
}

function validateAnswer(question: QuestionDefinition, value: AnswerValue, policy: CompiledQuestionnaire["policy"]): string[] {
  if (isUnknown(value)) return [];
  if (value === null) return question.nullable ? [] : ["NULL_NOT_ALLOWED"];
  const errors: string[] = [];
  if (typeof value === "string" && value.length > policy.maxStringLength) return ["MAX_LENGTH"];
  const exact = exactValue(value);
  const structured = typeof value === "object" && value !== null && !Array.isArray(value);
  const record = structured ? value as Readonly<Record<string, unknown>> : {};
  const stringTypes = ["SINGLE_CHOICE", "SHORT_TEXT", "LONG_TEXT", "CURRENCY", "EMAIL", "PHONE", "URL", "ADDRESS", "GEO_AREA", "FILE", "IMAGE"];
  if (question.type === "YES_NO" && typeof value !== "boolean") errors.push("TYPE_MISMATCH");
  else if (stringTypes.includes(question.type) && typeof value !== "string") errors.push("TYPE_MISMATCH");
  else if (question.type === "DATE" && (typeof value !== "string" || !dateValid(value))) errors.push("TYPE_MISMATCH");
  else if (question.type === "DATE_RANGE" && (!structured || record.kind !== "DATE_RANGE" || typeof record.start !== "string" || typeof record.end !== "string" || !dateValid(record.start) || !dateValid(record.end) || record.start > record.end)) errors.push("TYPE_MISMATCH");
  else if (question.type === "TIME" && (!structured || record.kind !== "LOCAL_TIME" || typeof record.localDate !== "string" || typeof record.localTime !== "string" || typeof record.timeZone !== "string" || !["EARLIER", "LATER", "REJECT"].includes(String(record.dstPolicy)) || resolveLocalTimeEpoch(record as unknown as { localDate: string; localTime: string; timeZone: string; dstPolicy: "EARLIER" | "LATER" | "REJECT" }) === undefined)) errors.push("INVALID_LOCAL_TIME");
  else if (question.type === "MONEY" && (!structured || record.kind !== "MONEY" || typeof record.amountMinor !== "string" || typeof record.currency !== "string" || !exactInteger(record.amountMinor) || !/^[A-Z]{3}$/.test(record.currency))) errors.push("TYPE_MISMATCH");
  else if (["INTEGER", "RATING_5", "RATING_10"].includes(question.type) && (!structured || record.kind !== "INTEGER" || typeof record.value !== "string" || !exactInteger(record.value))) errors.push("TYPE_MISMATCH");
  else if (["DECIMAL", "PERCENTAGE", "QUANTITY", "UNIT_VALUE"].includes(question.type) && (!structured || record.kind !== "DECIMAL" || typeof record.value !== "string" || !isNormalizedDecimal(record.value))) errors.push("TYPE_MISMATCH");
  else if (["MULTIPLE_CHOICE", "MULTI_FILE", "PRODUCT_LIST", "SITE_LIST", "MILESTONE_LIST"].includes(question.type) && !Array.isArray(value)) errors.push("TYPE_MISMATCH");
  else if (["TABLE", "REPEATER"].includes(question.type) && !Array.isArray(value)) errors.push("TYPE_MISMATCH");
  else if (["CONTACT", "ORGANIZATION", "BUDGET_BREAKDOWN"].includes(question.type) && !structured) errors.push("TYPE_MISMATCH");
  if (errors.length > 0) return errors;
  let effectiveExact = exact;
  if (effectiveExact !== undefined && question.numeric) {
    effectiveExact = roundDecimal(effectiveExact, question.numeric.scale, question.numeric.rounding);
    const shape = decimalShape(effectiveExact);
    if (!shape || shape.digits > question.numeric.precision) errors.push("NUMERIC_PRECISION");
  }
  if ((question.type === "TABLE" || question.type === "REPEATER") && question.structured && Array.isArray(value)) {
    const minimum = question.structured.kind === "TABLE" ? question.structured.minRows : question.structured.minItems;
    const maximum = question.structured.kind === "TABLE" ? question.structured.maxRows : question.structured.maxItems;
    const fields = question.structured.kind === "TABLE" ? question.structured.columns : question.structured.children;
    if (value.length < minimum) errors.push("MIN_ITEMS");
    if (value.length > maximum) errors.push("MAX_ITEMS");
    for (const item of value) {
      if (typeof item !== "object" || item === null || Array.isArray(item)) { errors.push("STRUCTURED_SCHEMA"); continue; }
      const itemRecord = item as Readonly<Record<string, AnswerValue>>;
      const expected = fields.map((field) => field.key).sort(compareCodePoints);
      const actual = Object.keys(itemRecord).sort(compareCodePoints);
      if (canonicalize(expected) !== canonicalize(actual)) { errors.push("STRUCTURED_SCHEMA"); continue; }
      for (const field of fields) {
        const fieldQuestion: QuestionDefinition = {
          key: field.key, sectionKey: question.sectionKey, version: "1", type: field.type,
          requiredByDefault: !field.nullable, visibleByDefault: true, requiredForQuote: false, requiredForPublication: false, nullable: field.nullable,
          ...(field.options ? { options: field.options } : {}), ...(field.numeric ? { numeric: field.numeric } : {}),
          ...(field.validation ? { validation: field.validation } : {}),
        };
        if (validateAnswer(fieldQuestion, itemRecord[field.key] as AnswerValue, policy).length > 0) errors.push("STRUCTURED_FIELD_INVALID");
      }
    }
  }
  if (question.options) {
    const selected = Array.isArray(value) ? value : [value];
    if (selected.some((item) => typeof item !== "string" || !question.options?.includes(item))) errors.push("OPTION_NOT_ALLOWED");
  }
  const validation = question.validation;
  if (validation) {
    if (typeof value === "string" && validation.minLength !== undefined && value.length < validation.minLength) errors.push("MIN_LENGTH");
    if (typeof value === "string" && validation.maxLength !== undefined && value.length > validation.maxLength) errors.push("MAX_LENGTH");
    if (Array.isArray(value) && validation.minItems !== undefined && value.length < validation.minItems) errors.push("MIN_ITEMS");
    if (Array.isArray(value) && validation.maxItems !== undefined && value.length > validation.maxItems) errors.push("MAX_ITEMS");
    if (effectiveExact !== undefined && validation.minimum !== undefined && compareDecimal(effectiveExact, validation.minimum) < 0) errors.push("BELOW_MINIMUM");
    if (effectiveExact !== undefined && validation.maximum !== undefined && compareDecimal(effectiveExact, validation.maximum) > 0) errors.push("ABOVE_MAXIMUM");
    if (typeof value === "string" && validation.pattern !== undefined && !new RegExp(validation.pattern, "u").test(value)) errors.push("PATTERN_MISMATCH");
  }
  if (question.type === "PERCENTAGE" && effectiveExact !== undefined && (compareDecimal(effectiveExact, "0") < 0 || compareDecimal(effectiveExact, "100") > 0)) errors.push("PERCENTAGE_RANGE");
  if (question.type === "RATING_5" && effectiveExact !== undefined && (compareDecimal(effectiveExact, "1") < 0 || compareDecimal(effectiveExact, "5") > 0)) errors.push("RATING_RANGE");
  if (question.type === "RATING_10" && effectiveExact !== undefined && (compareDecimal(effectiveExact, "1") < 0 || compareDecimal(effectiveExact, "10") > 0)) errors.push("RATING_RANGE");
  return errors;
}

function isIanaTimeZone(value: string): boolean {
  try { new Intl.DateTimeFormat("en", { timeZone: value }).format(0); return value.includes("/") || value === "UTC"; } catch { return false; }
}

const ACTION_PRIORITY: Readonly<Record<string, number>> = Object.freeze({
  BLOCK_PUBLICATION: 0, BLOCK_RFQ: 0, REQUIRE_HUMAN_REVIEW: 0,
  REQUIRE_QUESTION: 1, OPTIONAL_QUESTION: 1,
  SHOW_QUESTION: 2, HIDE_QUESTION: 2, SHOW_SECTION: 2, HIDE_SECTION: 2,
  ADD_VALIDATION_ERROR: 3, SET_ANSWER_VALIDITY: 3, REQUEST_DOCUMENT: 3,
  ADD_SCORE: 4,
  CREATE_ANOMALY: 5, CREATE_RISK: 5, CREATE_RECOMMENDATION: 5, CREATE_OPPORTUNITY: 5,
  ASSOCIATE_SOLUTION_LEVEL: 5, SUGGEST_SERVICE: 5, START_CHILD_DIAGNOSTIC: 5,
});

function isNormalizedDecimal(value: string): boolean {
  try { return normalizeDecimal(value) === value; } catch { return false; }
}

function actionPriority(type: RuleAction["type"]): number {
  const priority = ACTION_PRIORITY[type];
  if (priority === undefined) throw new QuestionEngineError("INVALID_AST");
  return priority;
}

function conflictKey(action: RuleAction): string | undefined {
  if (["REQUIRE_QUESTION", "OPTIONAL_QUESTION"].includes(action.type)) return `required:${action.target}`;
  if (["SHOW_QUESTION", "HIDE_QUESTION"].includes(action.type)) return `visible:${action.target}`;
  if (["SHOW_SECTION", "HIDE_SECTION"].includes(action.type)) return `section:${action.target}`;
  return undefined;
}

export function evaluateQuestionnaire(questionnaire: CompiledQuestionnaire, input: EvaluationInput): EvaluationResult {
  const runtime: Runtime = { operations: 0, started: performance.now(), questionnaire };
  try {
    if (!isUtcInstant(input.evaluatedAt)) throw new QuestionEngineError("INVALID_DATE_TIME");
    if (Buffer.byteLength(canonicalize(input), "utf8") > questionnaire.policy.maxInputBytes) throw new QuestionEngineError("BUDGET_EXCEEDED");
    const questionMap = new Map(questionnaire.questions.map((question) => [question.key, question]));
    if (Object.keys(input.answers).some((key) => !questionMap.has(key))) throw new QuestionEngineError("INVALID_REFERENCE");
    if (Object.keys(input.previousAnswers ?? {}).some((key) => !questionMap.has(key)) || Object.keys(input.prefills ?? {}).some((key) => !questionMap.has(key))) throw new QuestionEngineError("INVALID_REFERENCE");
    const answers: Record<string, AnswerValue> = {};
    const prefilled: string[] = [];
    const prefillTrace: { questionKey: string; source: string; version: string; freshUntil: string }[] = [];
    const coercions: { questionKey: string; coercion: Coercion }[] = [];
    for (const question of questionnaire.questions) {
      tick(runtime);
      let raw = input.answers[question.key];
      const prefill = input.prefills?.[question.key];
      if (prefill?.authorized && !isUtcInstant(prefill.freshUntil)) throw new QuestionEngineError("INVALID_DATE_TIME");
      if (isUnknown(raw) && prefill?.authorized && isUtcInstant(prefill.freshUntil) && Date.parse(prefill.freshUntil) >= Date.parse(input.evaluatedAt)) {
        raw = prefill.value;
        prefilled.push(question.key);
        prefillTrace.push({ questionKey: question.key, source: prefill.source, version: prefill.version, freshUntil: prefill.freshUntil });
      }
      if (raw !== undefined) {
        const coerced = coerce(question, raw);
        answers[question.key] = coerced.value;
        if (coerced.coercion) coercions.push({ questionKey: question.key, coercion: coerced.coercion });
      }
    }
    const trace: RuleTrace[] = [];
    const actions: AppliedAction[] = [];
    for (const rule of [...questionnaire.rules].sort((a, b) => compareCodePoints(a.key, b.key))) {
      const before = runtime.operations;
      const outcome = evaluateCondition(rule.condition, answers, input.previousAnswers ?? {}, runtime);
      trace.push({ ruleKey: rule.key, outcome, operations: runtime.operations - before, explanation: outcome === "TRUE" ? "RULE_TRIGGERED" : outcome === "UNKNOWN" ? "UNKNOWN_DEPENDENCY" : "CONDITION_NOT_MET" });
      if (outcome === "TRUE") rule.actions.forEach((action, actionIndex) => actions.push({ ...action, ruleKey: rule.key, rulePriority: rule.priority, actionIndex, categoryPriority: actionPriority(action.type) }));
    }
    actions.sort((a, b) => a.categoryPriority - b.categoryPriority || a.rulePriority - b.rulePriority || compareCodePoints(a.ruleKey, b.ruleKey) || a.actionIndex - b.actionIndex);
    const conflicts = new Map<string, string>();
    for (const action of actions) {
      tick(runtime);
      const key = conflictKey(action);
      if (key && conflicts.has(key) && conflicts.get(key) !== action.type) throw new QuestionEngineError("ACTION_CONFLICT");
      if (key) conflicts.set(key, action.type);
    }
    const visible = new Map(questionnaire.questions.map((question) => [question.key, question.visibleByDefault]));
    const visibleSections = new Map(questionnaire.questions.map((question) => [question.sectionKey, true]));
    const required = new Map(questionnaire.questions.map((question) => [question.key, question.requiredByDefault]));
    const errors: { questionKey: string; code: string }[] = [];
    let score = "0";
    const scores: Record<string, string> = {};
    let rfqBlocked = false;
    let publicationBlocked = false;
    const anomalies: string[] = [];
    for (const action of actions) {
      if (action.type === "BLOCK_RFQ") rfqBlocked = true;
      else if (action.type === "BLOCK_PUBLICATION") publicationBlocked = true;
      else if (action.type === "REQUIRE_QUESTION" && action.target) required.set(action.target, true);
      else if (action.type === "OPTIONAL_QUESTION" && action.target) required.set(action.target, false);
      else if (action.type === "SHOW_QUESTION" && action.target) visible.set(action.target, true);
      else if (action.type === "HIDE_QUESTION" && action.target) visible.set(action.target, false);
      else if (action.type === "SHOW_SECTION" && action.target) visibleSections.set(action.target, true);
      else if (action.type === "HIDE_SECTION" && action.target) visibleSections.set(action.target, false);
      else if (action.type === "ADD_VALIDATION_ERROR" && action.target) errors.push({ questionKey: action.target, code: action.messageKey ?? "RULE_VALIDATION_FAILED" });
      else if (action.type === "ADD_SCORE" && action.value && action.target) {
        score = addDecimal(score, action.value);
        const questionScore = addDecimal(scores[action.target] ?? "0", action.value);
        scores[action.target] = questionScore;
        const maximum = questionMap.get(action.target)?.scoreMaximum;
        if (maximum !== undefined && compareDecimal(questionScore, maximum) > 0) throw new QuestionEngineError("EVALUATION_FAILED");
      }
      else if (action.type === "CREATE_ANOMALY" && action.target) anomalies.push(action.target);
    }
    if (compareDecimal(score, questionnaire.policy.minimumScore) < 0 || compareDecimal(score, questionnaire.policy.maximumScore) > 0) throw new QuestionEngineError("EVALUATION_FAILED");
    for (const question of questionnaire.questions) {
      tick(runtime);
      const answer = Object.prototype.hasOwnProperty.call(answers, question.key) ? answers[question.key] as AnswerValue : UNKNOWN;
      for (const code of validateAnswer(question, answer, questionnaire.policy)) errors.push({ questionKey: question.key, code });
    }
    const visibleQuestions = questionnaire.questions.filter((question) => visible.get(question.key) && visibleSections.get(question.sectionKey)).map((question) => question.key).sort(compareCodePoints);
    const requiredQuestions = questionnaire.questions.filter((question) => visible.get(question.key) && visibleSections.get(question.sectionKey) && required.get(question.key)).map((question) => question.key).sort(compareCodePoints);
    const missingQuestions = requiredQuestions.filter((key) => isUnknown(answers[key]) || (answers[key] !== undefined && isEmpty(answers[key] as AnswerValue)));
    for (const question of questionnaire.questions) {
      const invalid = errors.some((error) => error.questionKey === question.key);
      const actuallyVisible = visible.get(question.key) && visibleSections.get(question.sectionKey);
      if (actuallyVisible && question.requiredForQuote && (missingQuestions.includes(question.key) || invalid)) rfqBlocked = true;
      if (actuallyVisible && question.requiredForPublication && (missingQuestions.includes(question.key) || invalid)) publicationBlocked = true;
    }
    const answered = requiredQuestions.filter((key) => !missingQuestions.includes(key) && !errors.some((error) => error.questionKey === key)).length;
    const basisPoints = requiredQuestions.length === 0 ? 10_000 : Number((BigInt(answered) * 10_000n) / BigInt(requiredQuestions.length));
    const { correlationId: _correlationId, ...businessInput } = input;
    const inputHash = canonicalHash({ input: businessInput, releaseId: questionnaire.releaseId, questionnaireVersion: questionnaire.questionnaireVersion, snapshotHash: questionnaire.snapshotHash, policyVersion: questionnaire.policy.version, engineVersion: questionnaire.engineVersion });
    return deepFreeze({ inputHash, snapshotHash: questionnaire.snapshotHash, visibleQuestions, requiredQuestions, prefilledQuestions: prefilled.sort(compareCodePoints), prefillTrace: prefillTrace.sort((a, b) => compareCodePoints(a.questionKey, b.questionKey)), missingQuestions, errors, completeness: { answered, required: requiredQuestions.length, basisPoints }, score, scores: Object.fromEntries(Object.entries(scores).sort(([a], [b]) => compareCodePoints(a, b))), actions, anomalies: [...new Set(anomalies)].sort(compareCodePoints), rfqBlocked, publicationBlocked, trace, coercions });
  } catch (error) {
    const correlationId = input.correlationId && /^[A-Za-z0-9_-]{1,80}$/.test(input.correlationId) ? input.correlationId : "question-engine";
    if (error instanceof QuestionEngineError) throw new QuestionEngineError(error.code, correlationId);
    throw new QuestionEngineError("EVALUATION_FAILED", correlationId);
  }
}
