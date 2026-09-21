import { describe, expect, it } from "vitest";
import { canonicalizeAnswer, parseQuestionValidation, parseStructuredFields } from "./model";

describe("questionnaire answer canonicalization", () => {
  it("keeps exact decimals and money as strings", () => {
    expect(canonicalizeAnswer({ type: "DECIMAL", values: ["9007199254740993.25"], nullable: false, clear: false })).toEqual({ success: true, value: { kind: "DECIMAL", value: "9007199254740993.25" } });
    expect(canonicalizeAnswer({ type: "MONEY", values: [], amountMinor: "900719925474099300", currency: "MAD", nullable: false, clear: false })).toEqual({ success: true, value: { kind: "MONEY", amountMinor: "900719925474099300", currency: "MAD" } });
  });
  it("rejects imprecise or malformed exact values", () => {
    expect(canonicalizeAnswer({ type: "DECIMAL", values: ["1e3"], nullable: false, clear: false })).toEqual({ success: false });
    expect(canonicalizeAnswer({ type: "MONEY", values: [], amountMinor: "12.50", currency: "MAD", nullable: false, clear: false })).toEqual({ success: false });
  });
  it("only permits null for nullable questions", () => {
    expect(canonicalizeAnswer({ type: "SHORT_TEXT", values: [], nullable: true, clear: true })).toEqual({ success: true, value: null });
    expect(canonicalizeAnswer({ type: "SHORT_TEXT", values: [], nullable: false, clear: true })).toEqual({ success: false });
  });
  it("parses only bounded published validation and structured metadata", () => {
    expect(parseQuestionValidation({ minLength: 2, maxLength: 20, minimum: "1.25", precision: 8, scale: 2, rounding: "HALF_EVEN" })).toEqual({ minLength: 2, maxLength: 20, minimum: "1.25" });
    expect(parseQuestionValidation({ maxLength: 20, unknown: true })).toEqual({});
    expect(parseStructuredFields({ type: "TABLE", structured: { kind: "TABLE", version: "1", minRows: 1, maxRows: 3, columns: [{ key: "count", type: "INTEGER", nullable: false, options: [], numeric: {}, validation: { minimum: "1" } }] } })).toEqual({ min: 1, max: 3, fields: [{ key: "count", type: "INTEGER", nullable: false, options: [], validation: { minimum: "1" } }] });
  });
});
