import { describe, expect, it } from "vitest";
import { getQuestionnaireMessages } from "./messages";
describe("questionnaire localization", () => { it("covers every answer type in both locales", () => { const fr = getQuestionnaireMessages("fr"), ar = getQuestionnaireMessages("ar"); expect(Object.keys(fr.types)).toHaveLength(33); expect(Object.keys(ar.types)).toEqual(Object.keys(fr.types)); expect(ar.title).not.toBe(fr.title); }); });
