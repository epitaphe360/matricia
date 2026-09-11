import { describe, expect, it } from "vitest";
import { canonicalHash, canonicalize, compileQuestionnaire, evaluateQuestionnaire, QuestionEngineError, UNKNOWN, type EnginePolicy, type QuestionnaireSnapshot, type RuleDefinition } from "./index";

const policy: EnginePolicy = {
  version: "POLICY_V1",
  maxAstDepth: 8,
  maxAstNodes: 64,
  maxQuestions: 100,
  maxRules: 20,
  maxActions: 40,
  maxStringLength: 256,
  maxRegexLength: 80,
  maxRegexCost: 300,
  maxOperations: 500,
  maxInputBytes: 20_000,
  maxDurationMs: 1_000,
  minimumScore: "-100",
  maximumScore: "100",
};

function snapshot(): QuestionnaireSnapshot {
  return {
    releaseId: "RELEASE_1",
    questionnaireVersion: "QUESTIONNAIRE_1",
    engineVersion: "ENGINE_1",
    allowedActionTargets: ["STAFFING_REVIEW"],
    policy,
    questions: [
      { key: "HAS_EMPLOYEES", sectionKey: "COMPANY", version: "1", type: "YES_NO", nullable: false, visibleByDefault: true, requiredByDefault: true, requiredForQuote: true, requiredForPublication: false },
      { key: "EMPLOYEE_COUNT", sectionKey: "COMPANY", version: "1", type: "INTEGER", nullable: false, visibleByDefault: false, requiredByDefault: false, requiredForQuote: true, requiredForPublication: false, coercion: "STRING_TO_INTEGER", numeric: { precision: 6, scale: 0, rounding: "HALF_EVEN" }, validation: { minimum: "1", maximum: "100000" }, scoreMaximum: "10" },
      { key: "RISK_NOTE", sectionKey: "RISK", version: "1", type: "SHORT_TEXT", nullable: true, visibleByDefault: true, requiredByDefault: false, requiredForQuote: false, requiredForPublication: false, validation: { maxLength: 50 } },
      { key: "START_DATE", sectionKey: "PLANNING", version: "1", type: "DATE", nullable: false, visibleByDefault: true, requiredByDefault: false, requiredForQuote: false, requiredForPublication: false },
      { key: "LOCAL_APPOINTMENT", sectionKey: "PLANNING", version: "1", type: "TIME", nullable: false, visibleByDefault: true, requiredByDefault: false, requiredForQuote: false, requiredForPublication: false },
      { key: "BUDGET", sectionKey: "FINANCE", version: "1", type: "MONEY", nullable: false, visibleByDefault: true, requiredByDefault: false, requiredForQuote: false, requiredForPublication: false },
    ],
    rules: [{
      key: "RULE_EMPLOYEES",
      version: "1",
      priority: 10,
      condition: { kind: "PREDICATE", operator: "EQ", questionKey: "HAS_EMPLOYEES", operand: true },
      actions: [
        { type: "REQUIRE_QUESTION", target: "EMPLOYEE_COUNT" },
        { type: "SHOW_QUESTION", target: "EMPLOYEE_COUNT" },
        { type: "ADD_SCORE", target: "EMPLOYEE_COUNT", value: "2.50" },
        { type: "CREATE_ANOMALY", target: "STAFFING_REVIEW" },
      ],
    }],
  };
}

describe("canonicalization", () => {
  it("sorts object keys, normalizes Unicode and excludes non-semantic metadata", () => {
    const left = { z: "e\u0301", a: 1, metadata: { ignored: true } };
    const right = { a: 1, z: "é", metadata: { ignored: false } };
    expect(canonicalize(left)).toBe(canonicalize(right));
    expect(canonicalHash(left)).toMatch(/^[0-9a-f]{64}$/);
  });

  it("refuses floating point and non-finite JSON numbers", () => {
    expect(() => canonicalize({ unsafe: 1.2 })).toThrowError("INVALID_INPUT");
    expect(() => canonicalize(Number.POSITIVE_INFINITY)).toThrowError("INVALID_INPUT");
  });

  it("rejects cyclic, non-plain and Unicode-colliding objects", () => {
    const cyclic: Record<string, unknown> = {};
    cyclic.self = cyclic;
    expect(() => canonicalize(cyclic)).toThrowError("INVALID_INPUT");
    expect(() => canonicalize(new Date())).toThrowError("INVALID_INPUT");
    expect(() => canonicalize({ "é": 1, "e\u0301": 2 })).toThrowError("INVALID_INPUT");
  });
});

describe("compiler validation", () => {
  it("produces the same snapshot hash regardless of question and rule object order", () => {
    const first = snapshot();
    const second: QuestionnaireSnapshot = { ...first, questions: [...first.questions].reverse(), rules: [...first.rules].reverse() };
    expect(compileQuestionnaire(first).snapshotHash).toBe(compileQuestionnaire(second).snapshotHash);
  });

  it("normalizes exact numeric snapshot fields before hashing", () => {
    const first = snapshot();
    const normalized: QuestionnaireSnapshot = { ...first, rules: first.rules.map((rule) => ({ ...rule, actions: rule.actions.map((action) => action.type === "ADD_SCORE" ? { ...action, value: "2.5" } : action) })) };
    expect(compileQuestionnaire(first).snapshotHash).toBe(compileQuestionnaire(normalized).snapshotHash);
  });

  it("rejects unknown references, dangerous regexes and financial rules", () => {
    const base = snapshot();
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "PREDICATE", operator: "EQ", questionKey: "MISSING", operand: true } }] })).toThrowError("INVALID_REFERENCE");
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "PREDICATE", operator: "REGEX", questionKey: "RISK_NOTE", operand: "(a+)+$" } }] })).toThrowError("INVALID_REGEX");
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, actions: [{ type: "CREATE_RECOMMENDATION", target: "OUTSIDE_RELEASE" }] }] })).toThrowError("INVALID_REFERENCE");
  });

  it("rejects excessive depth, self-reference and incompatible actions", () => {
    const base = snapshot();
    let condition = base.rules[0]!.condition;
    for (let index = 0; index < 10; index += 1) condition = { kind: "NOT", child: condition };
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition }] })).toThrowError("INVALID_AST");
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "PREDICATE", operator: "IS_NOT_EMPTY", questionKey: "EMPLOYEE_COUNT" }, actions: [{ type: "SHOW_QUESTION", target: "EMPLOYEE_COUNT" }] }] })).toThrowError("RULE_CYCLE");
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, actions: [{ type: "SHOW_QUESTION", target: "EMPLOYEE_COUNT" }, { type: "HIDE_QUESTION", target: "EMPLOYEE_COUNT" }] }] })).toThrowError("ACTION_CONFLICT");
  });

  it("rejects runtime JSON operators/actions and incompatible operands outside the allowlist", () => {
    const base = snapshot();
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "PREDICATE", operator: "EXEC", questionKey: "HAS_EMPLOYEES", operand: true } as never }] })).toThrowError("INVALID_AST");
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, actions: [{ type: "CALL_HTTP" } as never] }] })).toThrowError("INVALID_AST");
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "PREDICATE", operator: "EQ", questionKey: "HAS_EMPLOYEES", operand: "true" } }] })).toThrowError("INVALID_TYPE");
  });

  it("rejects mismatched coercion schemas and bounded question counts", () => {
    const base = snapshot();
    expect(() => compileQuestionnaire({ ...base, questions: base.questions.map((question) => question.key === "HAS_EMPLOYEES" ? { ...question, coercion: "STRING_TO_DECIMAL" as const } : question) })).toThrowError("INVALID_SNAPSHOT");
    expect(() => compileQuestionnaire({ ...base, policy: { ...policy, maxQuestions: 2 } })).toThrowError("INVALID_SNAPSHOT");
  });

  it("allows scoring a question from its own answer because scoring does not mutate dependencies", () => {
    const base = snapshot();
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "PREDICATE", operator: "GT", questionKey: "EMPLOYEE_COUNT", operand: { kind: "INTEGER", value: "10" } }, actions: [{ type: "ADD_SCORE", target: "EMPLOYEE_COUNT", value: "1" }] }] })).not.toThrow();
  });

  it("rejects a demonstrably unreachable AND branch", () => {
    const base = snapshot();
    expect(() => compileQuestionnaire({ ...base, rules: [{ ...base.rules[0]!, condition: { kind: "GROUP", operator: "AND", children: [
      { kind: "PREDICATE", operator: "EQ", questionKey: "HAS_EMPLOYEES", operand: true },
      { kind: "PREDICATE", operator: "EQ", questionKey: "HAS_EMPLOYEES", operand: false },
    ] } }] })).toThrowError("INVALID_AST");
  });
});

describe("deterministic evaluation", () => {
  it("applies visibility, requiredness, exact scoring and canonical action order", () => {
    const compiled = compileQuestionnaire(snapshot());
    const input = { evaluatedAt: "2026-09-11T16:00:00Z", answers: { HAS_EMPLOYEES: true, EMPLOYEE_COUNT: "12" } } as const;
    const first = evaluateQuestionnaire(compiled, input);
    const second = evaluateQuestionnaire(compiled, input);
    expect(first).toEqual(second);
    expect(first.visibleQuestions).toContain("EMPLOYEE_COUNT");
    expect(first.requiredQuestions).toContain("EMPLOYEE_COUNT");
    expect(first.missingQuestions).toEqual([]);
    expect(first.score).toBe("2.5");
    expect(first.scores).toEqual({ EMPLOYEE_COUNT: "2.5" });
    expect(first.actions.map((action) => action.type)).toEqual(["REQUIRE_QUESTION", "SHOW_QUESTION", "ADD_SCORE", "CREATE_ANOMALY"]);
    expect(first.coercions).toEqual([{ questionKey: "EMPLOYEE_COUNT", coercion: "STRING_TO_INTEGER" }]);
    expect(first.completeness).toEqual({ answered: 2, required: 2, basisPoints: 10_000 });
  });

  it("distinguishes UNKNOWN from explicit NULL without triggering visibility", () => {
    const compiled = compileQuestionnaire(snapshot());
    const missing = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: {} });
    expect(missing.trace[0]).toMatchObject({ outcome: "UNKNOWN", explanation: "UNKNOWN_DEPENDENCY" });
    expect(missing.visibleQuestions).not.toContain("EMPLOYEE_COUNT");
    const explicitNull = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { HAS_EMPLOYEES: null } });
    expect(explicitNull.trace[0]?.outcome).toBe("FALSE");
    expect(explicitNull.errors).toContainEqual({ questionKey: "HAS_EMPLOYEES", code: "NULL_NOT_ALLOWED" });
  });

  it("uses only authorized, fresh prefills and exposes their provenance decision", () => {
    const compiled = compileQuestionnaire(snapshot());
    const fresh = evaluateQuestionnaire(compiled, {
      evaluatedAt: "2026-09-11T16:00:00Z",
      answers: {},
      prefills: { HAS_EMPLOYEES: { value: false, source: "PROFILE", version: "7", freshUntil: "2026-09-12T00:00:00Z", authorized: true } },
    });
    expect(fresh.prefilledQuestions).toEqual(["HAS_EMPLOYEES"]);
    expect(fresh.prefillTrace).toEqual([{ questionKey: "HAS_EMPLOYEES", source: "PROFILE", version: "7", freshUntil: "2026-09-12T00:00:00Z" }]);
    const expired = evaluateQuestionnaire(compiled, {
      evaluatedAt: "2026-09-13T00:00:00Z",
      answers: {},
      prefills: { HAS_EMPLOYEES: { value: false, source: "PROFILE", version: "7", freshUntil: "2026-09-12T00:00:00Z", authorized: true } },
    });
    expect(expired.prefilledQuestions).toEqual([]);
    expect(expired.missingQuestions).toEqual(["HAS_EMPLOYEES"]);
  });

  it("applies section visibility to every question in canonical action order", () => {
    const base = snapshot();
    const compiled = compileQuestionnaire({ ...base, rules: [{ key: "RULE_HIDE_PLANNING", version: "1", priority: 1, condition: { kind: "PREDICATE", operator: "EQ", questionKey: "HAS_EMPLOYEES", operand: false }, actions: [{ type: "HIDE_SECTION", target: "PLANNING" }] }] });
    const result = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { HAS_EMPLOYEES: false } });
    expect(result.visibleQuestions).not.toContain("START_DATE");
    expect(result.visibleQuestions).not.toContain("LOCAL_APPOINTMENT");
  });

  it("validates exact money, dates, options and quote blocking without float", () => {
    const compiled = compileQuestionnaire(snapshot());
    const result = evaluateQuestionnaire(compiled, {
      evaluatedAt: "2026-09-11T16:00:00Z",
      answers: { HAS_EMPLOYEES: true, EMPLOYEE_COUNT: { kind: "INTEGER", value: "0" }, START_DATE: "2026-02-30", BUDGET: { kind: "MONEY", amountMinor: "10.5", currency: "mad" } },
    });
    expect(result.errors).toEqual(expect.arrayContaining([
      { questionKey: "EMPLOYEE_COUNT", code: "BELOW_MINIMUM" },
      { questionKey: "START_DATE", code: "TYPE_MISMATCH" },
      { questionKey: "BUDGET", code: "TYPE_MISMATCH" },
    ]));
    expect(result.rfqBlocked).toBe(true);
  });

  it("requires an IANA timezone and explicit DST policy for local times", () => {
    const compiled = compileQuestionnaire(snapshot());
    const valid = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { LOCAL_APPOINTMENT: { kind: "LOCAL_TIME", localDate: "2026-09-11", localTime: "09:30", timeZone: "Africa/Casablanca", dstPolicy: "REJECT" } } });
    expect(valid.errors).not.toContainEqual(expect.objectContaining({ questionKey: "LOCAL_APPOINTMENT" }));
    const invalid = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { LOCAL_APPOINTMENT: { kind: "LOCAL_TIME", localDate: "2026-09-11", localTime: "25:00", timeZone: "GMT+1", dstPolicy: "REJECT" } } });
    expect(invalid.errors).toContainEqual({ questionKey: "LOCAL_APPOINTMENT", code: "INVALID_LOCAL_TIME" });
  });

  it("enforces versioned numeric precision without rounding implicitly", () => {
    const compiled = compileQuestionnaire(snapshot());
    const result = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { EMPLOYEE_COUNT: { kind: "INTEGER", value: "1000000" } } });
    expect(result.errors).toContainEqual({ questionKey: "EMPLOYEE_COUNT", code: "NUMERIC_PRECISION" });
  });

  it("deep-freezes a cloned snapshot so caller mutation cannot bypass validation", () => {
    const mutable = snapshot();
    const compiled = compileQuestionnaire(mutable);
    const originalHash = compiled.snapshotHash;
    (mutable.rules as RuleDefinition[])[0] = { ...mutable.rules[0]!, key: "MUTATED" };
    expect(compiled.rules[0]?.key).toBe("RULE_EMPLOYEES");
    expect(compiled.snapshotHash).toBe(originalHash);
    expect(Object.isFrozen(compiled.rules[0]?.condition)).toBe(true);
  });

  it("supports explicit previous-answer change and date comparisons", () => {
    const base = snapshot();
    const compiled = compileQuestionnaire({
      ...base,
      rules: [
        { key: "RULE_CHANGED", version: "1", priority: 1, condition: { kind: "PREDICATE", operator: "CHANGED", questionKey: "RISK_NOTE" }, actions: [{ type: "REQUIRE_HUMAN_REVIEW" }] },
        { key: "RULE_DATE", version: "1", priority: 2, condition: { kind: "PREDICATE", operator: "DATE_BEFORE", questionKey: "START_DATE", operand: "2027-01-01" }, actions: [{ type: "BLOCK_PUBLICATION" }] },
      ],
    });
    const result = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { RISK_NOTE: "new", START_DATE: "2026-12-01" }, previousAnswers: { RISK_NOTE: "old" } });
    expect(result.trace.map((entry) => entry.outcome)).toEqual(["TRUE", "TRUE"]);
    expect(result.publicationBlocked).toBe(true);
  });

  it("fails closed with no partial result when the deterministic operation budget is exceeded", () => {
    const base = snapshot();
    const compiled = compileQuestionnaire({ ...base, policy: { ...policy, maxOperations: 2 } });
    expect(() => evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { HAS_EMPLOYEES: true } })).toThrowError("BUDGET_EXCEEDED");
  });

  it("fails closed when the UTF-8 input memory budget is exceeded", () => {
    const base = snapshot();
    const compiled = compileQuestionnaire({ ...base, policy: { ...policy, maxInputBytes: 80 } });
    expect(() => evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { RISK_NOTE: "é".repeat(100) } })).toThrowError("BUDGET_EXCEEDED");
  });

  it("rejects unknown answers and non-UTC evaluation instants", () => {
    const compiled = compileQuestionnaire(snapshot());
    expect(() => evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T12:00:00-04:00", answers: {} })).toThrowError("INVALID_DATE_TIME");
    expect(() => evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { FOREIGN: UNKNOWN } })).toThrowError("INVALID_REFERENCE");
  });

  it("returns stable neutral engine errors", () => {
    try {
      compileQuestionnaire({ ...snapshot(), rules: [{ ...snapshot().rules[0]!, condition: { kind: "PREDICATE", operator: "EQ", questionKey: "ABSENT", operand: true } }] });
    } catch (error) {
      expect(error).toBeInstanceOf(QuestionEngineError);
      expect(error).toMatchObject({ code: "INVALID_REFERENCE", correlationId: "question-engine" });
    }
  });

  it("propagates only a bounded caller correlation identifier on failure", () => {
    const compiled = compileQuestionnaire(snapshot());
    try {
      evaluateQuestionnaire(compiled, { correlationId: "req_ABC-123", evaluatedAt: "invalid", answers: {} });
    } catch (error) {
      expect(error).toMatchObject({ code: "INVALID_DATE_TIME", correlationId: "req_ABC-123", message: "INVALID_DATE_TIME" });
    }
  });
});
