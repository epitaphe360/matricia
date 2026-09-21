import { describe, expect, it } from "vitest";
import { getFranchiseDigestMessages } from "./messages";

describe("franchise digest messages", () => {
  it("keeps the same FR and AR contract", () => expect(Object.keys(getFranchiseDigestMessages("ar")).sort()).toEqual(Object.keys(getFranchiseDigestMessages("fr")).sort()));
  it("contains explicit privacy and scope guidance", () => { expect(getFranchiseDigestMessages("fr").noPersonalData).toContain("aucun nom"); expect(getFranchiseDigestMessages("ar").scopeTitle).toContain("التفويض"); });
});
