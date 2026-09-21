import { describe, expect, it } from "vitest";
import { onboardingProgressIndex } from "./progress";

describe("onboardingProgressIndex", () => {
  it("keeps trial as the last step and never starts it before VERIFIED", () => {
    expect(onboardingProgressIndex(null)).toBe(-1);
    expect(onboardingProgressIndex("PROFILE_IN_PROGRESS")).toBe(0);
    expect(onboardingProgressIndex("DOCUMENTS_REQUIRED")).toBe(1);
    expect(onboardingProgressIndex("UNDER_REVIEW")).toBe(2);
    expect(onboardingProgressIndex("VERIFIED")).toBe(3);
    expect(onboardingProgressIndex("VERIFIED", "TRIAL_ACTIVE")).toBe(4);
    expect(onboardingProgressIndex("REJECTED")).toBe(0);
  });
});
