import { describe, expect, it } from "vitest";
import { expiredDocuments, isDocumentExpired, reusableDocuments } from "./expiry";

describe("document expiry", () => {
  const today = "2026-09-21";

  it("compares calendar dates without inventing a time-of-day block", () => {
    expect(isDocumentExpired(null, today)).toBe(false);
    expect(isDocumentExpired("2026-09-21", today)).toBe(false);
    expect(isDocumentExpired("2026-09-20", today)).toBe(true);
    expect(isDocumentExpired("2026-09-22", today)).toBe(false);
  });

  it("splits reusable and expired documents for reuse in a request or mission", () => {
    const documents = [
      { id: "a", expiresOn: null },
      { id: "b", expiresOn: "2026-09-20" },
      { id: "c", expiresOn: "2026-09-22" },
    ];
    expect(expiredDocuments(documents, today).map((item) => item.id)).toEqual(["b"]);
    expect(reusableDocuments(documents, today).map((item) => item.id)).toEqual(["a", "c"]);
  });
});
