import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  rpc: vi.fn(),
  from: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc, from: mocks.from }),
}));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("node:crypto", () => ({ randomUUID: () => "11111111-1111-4111-8111-111111111111" }));

import {
  decideRoleRequest,
  listOrganizationRoles,
  requestAdditionalRole,
  type RoleDecisionActionState,
  type RoleRequestActionState,
} from "./actions";

const requestIdle: RoleRequestActionState = { status: "idle" };
const decisionIdle: RoleDecisionActionState = { status: "idle" };
const userId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const organizationId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const membershipId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const otherMembershipId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const requestId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
const idempotencyKey = "ffffffff-ffff-4fff-8fff-ffffffffffff";

function requestForm(overrides: Record<string, string> = {}) {
  const form = new FormData();
  for (const [key, value] of Object.entries({
    organizationId,
    requestedRoleCode: "PROVIDER_OWNER",
    idempotencyKey,
    locale: "fr",
    ...overrides,
  })) form.set(key, value);
  return form;
}

function decisionForm(overrides: Record<string, string> = {}) {
  const form = new FormData();
  for (const [key, value] of Object.entries({
    requestId,
    decision: "APPROVE",
    confirmed: "yes",
    locale: "ar",
    ...overrides,
  })) form.set(key, value);
  return form;
}

describe("role request mutations", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getUser.mockResolvedValue({ data: { user: { id: userId } }, error: null });
    mocks.rpc.mockResolvedValue({ data: { outcome: "ROLE_REQUESTED", request_id: requestId }, error: null });
  });

  it("valide organisation, rôle, locale et clé avant Auth", async () => {
    await expect(requestAdditionalRole(requestIdle, requestForm({ requestedRoleCode: "SUPER_ADMIN", idempotencyKey: "bad" })))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("demande un rôle additionnel avec idempotence et corrélation", async () => {
    await expect(requestAdditionalRole(requestIdle, requestForm())).resolves.toEqual({ status: "success", outcome: "ROLE_REQUESTED" });
    expect(mocks.rpc).toHaveBeenCalledWith("request_additional_organization_role", {
      p_organization_id: organizationId,
      p_requested_role_code: "PROVIDER_OWNER",
      p_idempotency_key: idempotencyKey,
      p_correlation_id: "11111111-1111-4111-8111-111111111111",
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/fr/organisation/roles");
  });

  it("préserve le résultat idempotent déjà en attente", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "ROLE_REQUEST_ALREADY_PENDING" }, error: null });
    await expect(requestAdditionalRole(requestIdle, requestForm())).resolves.toEqual({ status: "success", outcome: "ROLE_REQUEST_ALREADY_PENDING" });
  });

  it("rejette une réponse RPC inattendue sans exposer son contenu", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "SECRET_INTERNAL" }, error: null });
    const result = await requestAdditionalRole(requestIdle, requestForm());
    expect(result).toEqual({ status: "error", reason: "UNAVAILABLE" });
    expect(JSON.stringify(result)).not.toContain("SECRET");
  });

  it("décide une demande confirmée avec le booléen serveur attendu", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: null });
    await expect(decideRoleRequest(decisionIdle, decisionForm())).resolves.toEqual({ status: "success", decision: "APPROVE" });
    expect(mocks.rpc).toHaveBeenCalledWith("decide_organization_access_request", {
      p_request_id: requestId,
      p_approve: true,
      p_correlation_id: "11111111-1111-4111-8111-111111111111",
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/ar/organisation/roles");
  });

  it("valide le refus et sa confirmation avant Auth", async () => {
    await expect(decideRoleRequest(decisionIdle, decisionForm({ decision: "REJECT", confirmed: "no" })))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("neutralise les erreurs d’autorisation du RPC de décision", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "CENTRAL_COMPLIANCE_APPROVAL_REQUIRED" } });
    const result = await decideRoleRequest(decisionIdle, decisionForm());
    expect(result).toEqual({ status: "error", reason: "UNAVAILABLE" });
    expect(JSON.stringify(result)).not.toContain("CENTRAL");
  });
});

describe("listOrganizationRoles", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getUser.mockResolvedValue({ data: { user: { id: userId } }, error: null });
    mocks.rpc.mockResolvedValue({
      data: [{ requirement_satisfied: true, matched_role_codes: [] }],
      error: null,
    });
  });

  it("compose uniquement les données visibles et interdit décision propre ou centrale à l’approbateur local", async () => {
    const ownResult = { data: [{ id: membershipId, organization_id: organizationId, user_id: userId, status: "ACTIVE" }], error: null };
    const membershipsResult = { data: [
      { id: membershipId, organization_id: organizationId, user_id: userId, status: "ACTIVE" },
      { id: otherMembershipId, organization_id: organizationId, user_id: "12121212-1212-4212-8212-121212121212", status: "ACTIVE" },
    ], error: null };
    const organizationsResult = { data: [{ id: organizationId, display_name: "Atlas Conseil" }], error: null };
    const requestsResult = { data: [
      { id: requestId, organization_id: organizationId, requester_user_id: userId, requested_role_code: "PROVIDER_OWNER", status: "PENDING", requires_central_approval: true, created_at: "2026-09-11T10:00:00Z", decided_at: null },
      { id: "13131313-1313-4313-8313-131313131313", organization_id: organizationId, requester_user_id: "12121212-1212-4212-8212-121212121212", requested_role_code: "CLIENT_MEMBER", status: "PENDING", requires_central_approval: false, created_at: "2026-09-11T11:00:00Z", decided_at: null },
    ], error: null };
    const rolesResult = { data: [
      { membership_id: membershipId, role_code: "CLIENT_ADMIN", revoked_at: null },
      { membership_id: otherMembershipId, role_code: "CLIENT_VIEWER", revoked_at: null },
    ], error: null };
    mocks.from.mockImplementation((table: string) => {
      if (table === "organization_memberships") {
        return {
          select: () => ({
            eq: async () => ownResult,
            in: async () => membershipsResult,
          }),
        };
      }
      if (table === "organizations") return { select: () => ({ in: async () => organizationsResult }) };
      if (table === "organization_access_requests") return { select: () => ({ order: async () => requestsResult }) };
      if (table === "organization_member_roles") return { select: () => ({ in: async () => rolesResult }) };
      throw new Error("unexpected table " + table);
    });

    const result = await listOrganizationRoles();
    expect(result.status).toBe("success");
    if (result.status !== "success") throw new Error("unexpected result");
    expect(result.organizations).toEqual([{ id: organizationId, displayName: "Atlas Conseil", currentRoles: ["CLIENT_ADMIN"] }]);
    expect(result.memberships).toHaveLength(2);
    expect(result.requests.map((request) => ({ isOwn: request.isOwn, canDecide: request.canDecide, central: request.requiresCentralApproval })))
      .toEqual([
        { isOwn: true, canDecide: false, central: true },
        { isOwn: false, canDecide: true, central: false },
      ]);
    expect(JSON.stringify(result)).not.toContain("requester_user_id");
    expect(JSON.stringify(result)).not.toContain("user_id");
  });

  it("arrête toute lecture tenant sans identité vérifiée", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null }, error: null });
    await expect(listOrganizationRoles()).resolves.toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(mocks.from).not.toHaveBeenCalled();
  });

  it("autorise une décision centrale uniquement lorsque le rôle sensible et son exigence MFA sont satisfaits", async () => {
    const centralRequestId = "14141414-1414-4414-8414-141414141414";
    mocks.rpc.mockResolvedValue({
      data: [{ requirement_satisfied: true, matched_role_codes: ["COMPLIANCE_MANAGER"] }],
      error: null,
    });
    mocks.from.mockImplementation((table: string) => {
      if (table === "organization_memberships") {
        return { select: () => ({ eq: async () => ({ data: [], error: null }) }) };
      }
      if (table === "organization_access_requests") {
        return { select: () => ({ order: async () => ({ data: [{
          id: centralRequestId,
          organization_id: organizationId,
          requester_user_id: "15151515-1515-4515-8515-151515151515",
          requested_role_code: "FRANCHISE_OWNER",
          status: "PENDING",
          requires_central_approval: true,
          created_at: "2026-09-11T12:00:00Z",
          decided_at: null,
        }], error: null }) }) };
      }
      throw new Error("unexpected table " + table);
    });
    const result = await listOrganizationRoles();
    expect(result.status).toBe("success");
    if (result.status !== "success") throw new Error("unexpected result");
    expect(result.requests[0]).toMatchObject({ id: centralRequestId, requiresCentralApproval: true, canDecide: true });
  });
});
