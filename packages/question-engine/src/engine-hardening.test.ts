import { describe, expect, it } from "vitest";
import {
  canonicalize, compileQuestionnaire, evaluateQuestionnaire, resolveLocalTimeEpoch, roundDecimal,
  type ActionType, type EnginePolicy, type PredicateOperator, type QuestionDefinition, type QuestionnaireSnapshot, type RuleAction,
} from "./index";

const basePolicy: EnginePolicy = {
  version: "POLICY_HARDENED_V1", maxAstDepth: 12, maxAstNodes: 200, maxQuestions: 100, maxRules: 100,
  maxActions: 200, maxStringLength: 60_000, maxRegexLength: 100, maxRegexCost: 500,
  maxOperations: 20_000, maxInputBytes: 100_000, maxDurationMs: 5_000, minimumScore: "-100", maximumScore: "100",
};

const yesNo = (key: string, sectionKey = "MAIN"): QuestionDefinition => ({
  key, sectionKey, version: "1", type: "YES_NO", nullable: false, visibleByDefault: true,
  requiredByDefault: false, requiredForQuote: false, requiredForPublication: false,
});

function makeSnapshot(questions: readonly QuestionDefinition[], rules: QuestionnaireSnapshot["rules"] = [], policy = basePolicy): QuestionnaireSnapshot {
  return { releaseId: "REL", questionnaireVersion: "QV1", engineVersion: "EV1", allowedActionTargets: ["EXT"], policy, questions, rules };
}

describe("operator and action contracts", () => {
  it("executes every predicate operator with a typed operand", () => {
    const questions: QuestionDefinition[] = [
      yesNo("BOOL"),
      { ...yesNo("NUM"), type: "INTEGER", numeric: { precision: 6, scale: 0, rounding: "HALF_EVEN" } },
      { ...yesNo("TEXT"), type: "SHORT_TEXT" }, { ...yesNo("EMPTY"), type: "SHORT_TEXT" },
      { ...yesNo("CHOICES"), type: "MULTIPLE_CHOICE", options: ["A", "B"] }, { ...yesNo("DATE"), type: "DATE" },
      { ...yesNo("UNKNOWN_VALUE"), type: "SHORT_TEXT" },
    ];
    const conditions: readonly [PredicateOperator, QuestionnaireSnapshot["rules"][number]["condition"]][] = [
      ["EQ", { kind: "PREDICATE", operator: "EQ", questionKey: "BOOL", operand: true }],
      ["NE", { kind: "PREDICATE", operator: "NE", questionKey: "BOOL", operand: false }],
      ["GT", { kind: "PREDICATE", operator: "GT", questionKey: "NUM", operand: { kind: "INTEGER", value: "1" } }],
      ["LT", { kind: "PREDICATE", operator: "LT", questionKey: "NUM", operand: { kind: "INTEGER", value: "3" } }],
      ["IN", { kind: "PREDICATE", operator: "IN", questionKey: "BOOL", operand: [false, true] }],
      ["CONTAINS", { kind: "PREDICATE", operator: "CONTAINS", questionKey: "CHOICES", operand: "A" }],
      ["IS_EMPTY", { kind: "PREDICATE", operator: "IS_EMPTY", questionKey: "EMPTY" }],
      ["IS_NOT_EMPTY", { kind: "PREDICATE", operator: "IS_NOT_EMPTY", questionKey: "TEXT" }],
      ["REGEX", { kind: "PREDICATE", operator: "REGEX", questionKey: "TEXT", operand: "^[A-Z]+$" }],
      ["DATE_BEFORE", { kind: "PREDICATE", operator: "DATE_BEFORE", questionKey: "DATE", operand: "2027-01-01" }],
      ["DATE_AFTER", { kind: "PREDICATE", operator: "DATE_AFTER", questionKey: "DATE", operand: "2025-01-01" }],
      ["CHANGED", { kind: "PREDICATE", operator: "CHANGED", questionKey: "TEXT" }],
      ["IS_UNKNOWN", { kind: "PREDICATE", operator: "IS_UNKNOWN", questionKey: "UNKNOWN_VALUE" }],
    ];
    const rules = conditions.map(([operator, condition], index) => ({ key: `RULE_${operator}`, version: "1", priority: index, condition, actions: [{ type: "REQUIRE_HUMAN_REVIEW" as const }] }));
    const result = evaluateQuestionnaire(compileQuestionnaire(makeSnapshot(questions, rules)), {
      evaluatedAt: "2026-09-11T16:00:00Z", answers: { BOOL: true, NUM: { kind: "INTEGER", value: "2" }, TEXT: "ABC", EMPTY: "", CHOICES: ["A"], DATE: "2026-01-01" }, previousAnswers: { TEXT: "OLD" },
    });
    expect(Object.fromEntries(result.trace.map((item) => [item.ruleKey, item.outcome]))).toEqual(Object.fromEntries(conditions.map(([operator]) => [`RULE_${operator}`, "TRUE"])));
  });

  it("accepts and deterministically emits every action", () => {
    const all: readonly ActionType[] = ["BLOCK_PUBLICATION", "BLOCK_RFQ", "REQUIRE_QUESTION", "OPTIONAL_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION", "SHOW_SECTION", "HIDE_SECTION", "ADD_VALIDATION_ERROR", "ADD_SCORE", "CREATE_ANOMALY", "CREATE_RISK", "CREATE_RECOMMENDATION", "CREATE_OPPORTUNITY", "ASSOCIATE_SOLUTION_LEVEL", "REQUEST_DOCUMENT", "REQUIRE_HUMAN_REVIEW", "SUGGEST_SERVICE", "START_CHILD_DIAGNOSTIC", "SET_ANSWER_VALIDITY"];
    for (const type of all) {
      let action: RuleAction = { type };
      if (["REQUIRE_QUESTION", "OPTIONAL_QUESTION", "SHOW_QUESTION", "HIDE_QUESTION", "ADD_VALIDATION_ERROR", "ADD_SCORE", "SET_ANSWER_VALIDITY"].includes(type)) action = { type, target: "TARGET", ...(type === "ADD_SCORE" ? { value: "1" } : {}) };
      else if (["SHOW_SECTION", "HIDE_SECTION"].includes(type)) action = { type, target: "TARGET_SECTION" };
      else if (["CREATE_ANOMALY", "CREATE_RISK", "CREATE_RECOMMENDATION", "CREATE_OPPORTUNITY", "ASSOCIATE_SOLUTION_LEVEL", "REQUEST_DOCUMENT", "SUGGEST_SERVICE", "START_CHILD_DIAGNOSTIC"].includes(type)) action = { type, target: "EXT" };
      const rules = [{ key: `RULE_${type}`, version: "1", priority: 1, condition: { kind: "PREDICATE" as const, operator: "EQ" as const, questionKey: "TRIGGER", operand: true }, actions: [action] }];
      const result = evaluateQuestionnaire(compileQuestionnaire(makeSnapshot([yesNo("TRIGGER"), yesNo("TARGET", "TARGET_SECTION")], rules)), { evaluatedAt: "2026-09-11T16:00:00Z", answers: { TRIGGER: true } });
      expect(result.actions.map((item) => item.type), type).toEqual([type]);
    }
  });

  it("rejects operands that do not match IN and CONTAINS question types", () => {
    const questions = [yesNo("BOOL"), { ...yesNo("CHOICE"), type: "SINGLE_CHOICE" as const, options: ["A"] }, { ...yesNo("CHOICES"), type: "MULTIPLE_CHOICE" as const, options: ["A"] }];
    const rule = (condition: QuestionnaireSnapshot["rules"][number]["condition"]) => [{ key: "RULE_BAD", version: "1", priority: 1, condition, actions: [{ type: "BLOCK_RFQ" as const }] }];
    expect(() => compileQuestionnaire(makeSnapshot(questions, rule({ kind: "PREDICATE", operator: "IN", questionKey: "BOOL", operand: ["true"] })))).toThrowError("INVALID_TYPE");
    expect(() => compileQuestionnaire(makeSnapshot(questions, rule({ kind: "PREDICATE", operator: "IN", questionKey: "CHOICE", operand: ["A", "ABSENT"] })))).toThrowError("INVALID_TYPE");
    expect(() => compileQuestionnaire(makeSnapshot(questions, rule({ kind: "PREDICATE", operator: "CONTAINS", questionKey: "CHOICES", operand: "B" })))).toThrowError("INVALID_TYPE");
    expect(() => compileQuestionnaire(makeSnapshot(questions, rule({ kind: "PREDICATE", operator: "CONTAINS", questionKey: "BOOL", operand: true })))).toThrowError("INVALID_TYPE");
  });
});

describe("structured schemas and exact numerics", () => {
  const table: QuestionDefinition = { ...yesNo("LINES"), type: "TABLE", structured: { version: "TABLE_V1", kind: "TABLE", minRows: 1, maxRows: 2, columns: [
    { key: "CODE", type: "SHORT_TEXT", nullable: false, validation: { minLength: 1, maxLength: 4 } },
    { key: "AMOUNT", type: "DECIMAL", nullable: true, numeric: { precision: 5, scale: 2, rounding: "HALF_UP" }, validation: { minimum: "0" } },
  ] } };
  const repeater: QuestionDefinition = { ...yesNo("PEOPLE"), type: "REPEATER", structured: { version: "REP_V1", kind: "REPEATER", minItems: 1, maxItems: 2, children: [{ key: "ACTIVE", type: "YES_NO", nullable: false }] } };

  it("validates exact columns, children, versions and limits", () => {
    const compiled = compileQuestionnaire(makeSnapshot([table, repeater]));
    const valid = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { LINES: [{ CODE: "A", AMOUNT: { kind: "DECIMAL", value: "1.235" } }], PEOPLE: [{ ACTIVE: true }] } });
    expect(valid.errors).toEqual([]);
    const invalid = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00Z", answers: { LINES: [{ CODE: "ABCDE", AMOUNT: null, EXTRA: true }], PEOPLE: [] } });
    expect(invalid.errors).toEqual(expect.arrayContaining([{ questionKey: "LINES", code: "STRUCTURED_SCHEMA" }, { questionKey: "PEOPLE", code: "MIN_ITEMS" }]));
    expect(() => compileQuestionnaire(makeSnapshot([{ ...table, structured: { ...table.structured!, version: "" } as never }, repeater]))).toThrowError("INVALID_SNAPSHOT");
    const containsRow = [{ key: "RULE_ROW", version: "1", priority: 1, condition: { kind: "PREDICATE" as const, operator: "CONTAINS" as const, questionKey: "LINES", operand: { CODE: "A", AMOUNT: null } }, actions: [{ type: "BLOCK_RFQ" as const }] }];
    expect(() => compileQuestionnaire(makeSnapshot([table, repeater], containsRow))).not.toThrow();
    expect(() => compileQuestionnaire(makeSnapshot([table, repeater], [{ ...containsRow[0]!, condition: { ...containsRow[0]!.condition, operand: { CODE: "A", EXTRA: true } } }]))).toThrowError("INVALID_TYPE");
  });

  it("implements all versioned rounding modes with bigint arithmetic", () => {
    expect(roundDecimal("1.25", 1, "HALF_UP")).toBe("1.3");
    expect(roundDecimal("-1.25", 1, "HALF_UP")).toBe("-1.3");
    expect(roundDecimal("1.25", 1, "HALF_EVEN")).toBe("1.2");
    expect(roundDecimal("1.35", 1, "HALF_EVEN")).toBe("1.4");
    expect(roundDecimal("-1.29", 1, "DOWN")).toBe("-1.2");
    expect(roundDecimal("-1.21", 1, "UP")).toBe("-1.3");
    const decimal = { ...yesNo("N"), type: "DECIMAL" as const, numeric: { precision: 3, scale: 1, rounding: "HALF_UP" as const } };
    const roundedRule = [{ key: "RULE_ROUNDED", version: "1", priority: 1, condition: { kind: "PREDICATE" as const, operator: "EQ" as const, questionKey: "N", operand: { kind: "DECIMAL" as const, value: "1.3" } }, actions: [{ type: "BLOCK_RFQ" as const }] }];
    expect(evaluateQuestionnaire(compileQuestionnaire(makeSnapshot([decimal], roundedRule)), { evaluatedAt: "2026-09-11T16:00:00Z", answers: { N: { kind: "DECIMAL", value: "1.25" } } }).rfqBlocked).toBe(true);
    expect(() => compileQuestionnaire(makeSnapshot([{ ...yesNo("N"), type: "DECIMAL", numeric: { precision: 3, scale: 1, rounding: "FLOOR" as never } }]))).toThrowError("INVALID_SNAPSHOT");
  });
});

describe("time, regex, determinism and budgets", () => {
  it("resolves IANA DST folds and rejects gaps without guessing", () => {
    const earlier = resolveLocalTimeEpoch({ localDate: "2026-11-01", localTime: "01:30", timeZone: "America/New_York", dstPolicy: "EARLIER" });
    const later = resolveLocalTimeEpoch({ localDate: "2026-11-01", localTime: "01:30", timeZone: "America/New_York", dstPolicy: "LATER" });
    expect(later! - earlier!).toBe(3_600_000);
    expect(resolveLocalTimeEpoch({ localDate: "2026-11-01", localTime: "01:30", timeZone: "America/New_York", dstPolicy: "REJECT" })).toBeUndefined();
    expect(resolveLocalTimeEpoch({ localDate: "2026-03-08", localTime: "02:30", timeZone: "America/New_York", dstPolicy: "EARLIER" })).toBeUndefined();
  });

  it("rejects catastrophic regex constructions and accepts the documented bounded subset", () => {
    const text = { ...yesNo("TEXT"), type: "SHORT_TEXT" as const };
    const withPattern = (pattern: string) => makeSnapshot([{ ...text, validation: { pattern } }]);
    for (const pattern of ["(a+)+$", "^(a|aa)+$", "^a+a+$", "^(a)(?:\\1)+$", "^a{1,101}$", "[A-Z]+"]) expect(() => compileQuestionnaire(withPattern(pattern)), pattern).toThrowError("INVALID_REGEX");
    expect(() => compileQuestionnaire(withPattern("^[A-Z]+$"))).not.toThrow();
  });

  it("uses code-point ordering, excludes correlation metadata and deep-freezes results", () => {
    expect(canonicalize({ "ä": 1, z: 2 })).toBe('{"z":2,"ä":1}');
    expect(canonicalize({ "\u{1F600}": 1, "\uE000": 2 })).toBe('{"":2,"😀":1}');
    const compiled = compileQuestionnaire(makeSnapshot([yesNo("BOOL")]));
    const first = evaluateQuestionnaire(compiled, { correlationId: "A", evaluatedAt: "2026-09-11T16:00:00Z", answers: { BOOL: true } });
    const second = evaluateQuestionnaire(compiled, { correlationId: "B", evaluatedAt: "2026-09-11T16:00:00Z", answers: { BOOL: true } });
    expect(first.inputHash).toBe(second.inputHash);
    const contact = { ...yesNo("CONTACT"), type: "CONTACT" as const };
    const contactEngine = compileQuestionnaire(makeSnapshot([contact]));
    const contactA = evaluateQuestionnaire(contactEngine, { correlationId: "SAME", evaluatedAt: "2026-09-11T16:00:00Z", answers: { CONTACT: { correlationId: "BUSINESS_A" } } });
    const contactB = evaluateQuestionnaire(contactEngine, { correlationId: "SAME", evaluatedAt: "2026-09-11T16:00:00Z", answers: { CONTACT: { correlationId: "BUSINESS_B" } } });
    expect(contactA.inputHash).not.toBe(contactB.inputHash);
    expect(Object.isFrozen(first)).toBe(true);
    expect(Object.isFrozen(first.completeness)).toBe(true);
    expect(Object.isFrozen(first.visibleQuestions)).toBe(true);
    expect(Object.isFrozen(first.trace)).toBe(true);
  });

  it("maps malformed snapshot roots to the stable INVALID_SNAPSHOT contract", () => {
    const { proxy, revoke } = Proxy.revocable({}, {});
    revoke();
    for (const malformed of [null, undefined, [], {}, { policy: {} }, { policy: {}, questions: [], rules: [] }, proxy]) {
      try {
        compileQuestionnaire(malformed as never);
        throw new Error("expected compilation to fail");
      } catch (error) {
        expect(error).toMatchObject({ name: "QuestionEngineError", code: "INVALID_SNAPSHOT", message: "INVALID_SNAPSHOT" });
      }
    }
    expect(() => compileQuestionnaire({ ...makeSnapshot([yesNo("BOOL")]), questions: [null] } as never)).toThrowError("INVALID_SNAPSHOT");
  });

  it("rejects root and nested snapshot cycles as INVALID_SNAPSHOT", () => {
    const rootCycle = makeSnapshot([yesNo("BOOL")]) as QuestionnaireSnapshot & { self?: unknown };
    rootCycle.self = rootCycle;

    const nestedCycle = { kind: "GROUP", operator: "AND", children: [] as unknown[] };
    nestedCycle.children.push(nestedCycle);
    const nestedSnapshot = makeSnapshot([yesNo("BOOL")], [{
      key: "RULE_CYCLE", version: "1", priority: 1, condition: nestedCycle as never,
      actions: [{ type: "BLOCK_RFQ" }],
    }]);

    for (const malformed of [rootCycle, nestedSnapshot]) {
      try {
        compileQuestionnaire(malformed);
        throw new Error("expected compilation to fail");
      } catch (error) {
        expect(error).toMatchObject({ name: "QuestionEngineError", code: "INVALID_SNAPSHOT", message: "INVALID_SNAPSHOT" });
      }
    }
  });

  it("compiles the 6,000-question catalogue boundary and rejects 6,001", () => {
    const questions = Array.from({ length: 6_000 }, (_, index) => yesNo(`Q_${String(index).padStart(4, "0")}`));
    const largePolicy = { ...basePolicy, maxQuestions: 6_000, maxOperations: 20_000 };
    expect(compileQuestionnaire(makeSnapshot(questions, [], largePolicy)).questions).toHaveLength(6_000);
    expect(() => compileQuestionnaire(makeSnapshot([...questions, yesNo("Q_6000")], [], largePolicy))).toThrowError("INVALID_SNAPSHOT");
  });

  it("enforces the 50,000-byte canonical input boundary exactly", () => {
    const compiled = compileQuestionnaire(makeSnapshot([{ ...yesNo("TEXT"), type: "SHORT_TEXT" }], [], { ...basePolicy, maxInputBytes: 50_000 }));
    const shell = { evaluatedAt: "2026-09-11T16:00:00Z", answers: { TEXT: "" } };
    const overhead = Buffer.byteLength(canonicalize(shell), "utf8");
    expect(() => evaluateQuestionnaire(compiled, { ...shell, answers: { TEXT: "a".repeat(50_000 - overhead) } })).not.toThrow();
    expect(() => evaluateQuestionnaire(compiled, { ...shell, answers: { TEXT: "a".repeat(50_001 - overhead) } })).toThrowError("BUDGET_EXCEEDED");
  });

  it("compares prefill instants by epoch rather than ISO lexical order", () => {
    const compiled = compileQuestionnaire(makeSnapshot([yesNo("BOOL")]));
    const result = evaluateQuestionnaire(compiled, { evaluatedAt: "2026-09-11T16:00:00.900Z", answers: {}, prefills: { BOOL: { value: true, source: "PROFILE", version: "1", freshUntil: "2026-09-11T16:00:00Z", authorized: true } } });
    expect(result.prefilledQuestions).toEqual([]);
  });
});
