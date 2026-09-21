import { describe, expect, it } from "vitest";
import { canOpenNewRfq, newRequestBlockReason } from "./entitlement";

describe("canOpenNewRfq", () => {
  it("blocks expired trial and unpaid statuses without inventing a block when unknown", () => {
    expect(canOpenNewRfq(undefined)).toBe(true);
    expect(canOpenNewRfq(null)).toBe(true);
    expect(canOpenNewRfq("TRIAL_ACTIVE")).toBe(true);
    expect(canOpenNewRfq("ACTIVE")).toBe(true);
    expect(canOpenNewRfq("TRIAL_EXPIRED")).toBe(false);
    expect(canOpenNewRfq("SUSPENDED")).toBe(false);
    expect(canOpenNewRfq("PAST_DUE")).toBe(false);
    expect(canOpenNewRfq("CANCELLED")).toBe(false);
  });
});

describe("newRequestBlockReason", () => {
  it("prefers the trial block and otherwise flags expired documents", () => {
    expect(newRequestBlockReason({ subscriptionStatus: undefined, expiredDocumentCount: 0 })).toBeNull();
    expect(newRequestBlockReason({ subscriptionStatus: "TRIAL_EXPIRED", expiredDocumentCount: 2 })).toBe("trial");
    expect(newRequestBlockReason({ subscriptionStatus: "ACTIVE", expiredDocumentCount: 1 })).toBe("document");
    expect(newRequestBlockReason({ subscriptionStatus: "ACTIVE", expiredDocumentCount: 0 })).toBeNull();
  });
});
