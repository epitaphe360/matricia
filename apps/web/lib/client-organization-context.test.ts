import { describe, expect, it } from "vitest";
import { resolveClientOrganizationContext } from "./client-organization-context";

const first = "11111111-1111-4111-8111-111111111111";
const second = "22222222-2222-4222-8222-222222222222";

describe("resolveClientOrganizationContext", () => {
  it("requires an explicit organization when several memberships are authorized", () => {
    expect(resolveClientOrganizationContext([{ organization_id: first }, { organization_id: second }])).toEqual({
      status: "error",
      reason: "ORGANIZATION_SELECTION_REQUIRED",
    });
  });

  it("rejects a forged or malformed organization instead of falling back", () => {
    const memberships = [{ organization_id: first }];
    expect(resolveClientOrganizationContext(memberships, second)).toEqual({ status: "error", reason: "FORBIDDEN_ORGANIZATION" });
    expect(resolveClientOrganizationContext(memberships, "not-an-id")).toEqual({ status: "error", reason: "FORBIDDEN_ORGANIZATION" });
  });

  it("returns only the explicitly authorized organization", () => {
    expect(resolveClientOrganizationContext([{ organization_id: first }, { organization_id: second }], second)).toEqual({
      status: "success",
      membership: { organization_id: second },
    });
  });
});
