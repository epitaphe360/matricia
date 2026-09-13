import { describe, expect, it } from "vitest";
import { resolveSocialCredentialReference } from "./credential-resolver";

describe("server social credential resolver", () => {
  it("resolves an env reference only by its exact server variable", () => {
    expect(resolveSocialCredentialReference("env://SOCIAL_LINKEDIN", { SOCIAL_LINKEDIN: "opaque" })).toBe("opaque");
  });

  it("maps an opaque vault alias to its injected server secret", () => {
    expect(resolveSocialCredentialReference("vault://LINKEDIN_PRIMARY", { MATRICIA_VAULT_LINKEDIN_PRIMARY: "opaque" })).toBe("opaque");
  });

  it("fails closed for malformed, missing and empty references", () => {
    expect(resolveSocialCredentialReference("vault://../SECRET", {})).toBeNull();
    expect(resolveSocialCredentialReference("vault://MISSING", {})).toBeNull();
    expect(resolveSocialCredentialReference("env://EMPTY", { EMPTY: "" })).toBeNull();
  });
});
