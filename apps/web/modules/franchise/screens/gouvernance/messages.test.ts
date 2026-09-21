import { describe, expect, it } from "vitest";
import { getFranchiseMessages } from "./messages";
describe("franchise governance translations", () => { it("keeps FR/AR keys aligned", () => expect(Object.keys(getFranchiseMessages("ar")).sort()).toEqual(Object.keys(getFranchiseMessages("fr")).sort())); it("provides native Arabic content", () => expect(getFranchiseMessages("ar").itRuleText).toMatch(/[\u0600-\u06ff]/)); });
