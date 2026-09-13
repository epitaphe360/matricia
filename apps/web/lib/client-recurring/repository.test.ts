import { describe, expect, it, vi } from "vitest";
import { createClientRecurringRepository, type ClientRecurringSource } from "./repository";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
function source(overrides: Partial<ClientRecurringSource> = {}): ClientRecurringSource {
  return {
    user: async () => id(1),
    memberships: async () => ({ data: [{ id: id(13), organization_id: id(14) }], error: null }),
    roles: async () => ({ data: [{ membership_id: id(13), role_code: "CLIENT_OWNER", revoked_at: null }], error: null }),
    requests: async () => ({ data: [{ id: id(2), client_organization_id: id(14), current_version_id: id(3), status: "CONTRACTED", created_at: "2026-09-01T00:00:00Z" }], error: null }),
    requestVersions: async () => ({ data: [{ id: id(3), request_id: id(2), version_number: 4, description: "Clôture comptable", desired_date: "2026-10-01" }], error: null }),
    plans: async () => ({ data: [{ id: id(4), client_organization_id: id(14), template_request_id: id(2), status: "ACTIVE", current_version: 2, row_version: 2, updated_at: "2026-09-12T00:00:00Z" }], error: null }),
    planVersions: async () => ({ data: [{ id: id(5), plan_id: id(4), version_number: 2, cadence: "MONTHLY", starts_on: "2026-10-01", ends_on: null, status: "ACTIVE", reason: "Reprise du cycle" }], error: null }),
    occurrences: async () => ({ data: [{ id: id(6), plan_id: id(4), scheduled_on: "2026-10-01", generated_request_id: id(7), created_at: "2026-09-12T00:00:00Z" }], error: null }),
    rpc: vi.fn(), ...overrides,
  };
}
const identity = { idempotencyKey: id(8), correlationId: id(9) };
describe("client recurring repository", () => {
  it("assemble seulement la version courante avec une capacité explicite", async () => { const result = await createClientRecurringRepository(source()).load(); expect(result).toMatchObject({ status: "success", value: { access: { activeRole: "CLIENT_OWNER", canManage: true }, requests: [{ id: id(2), versionNumber: 4 }], plans: [{ id: id(4), currentVersion: 2, occurrences: [{ generatedRequestId: id(7) }] }] } }); });
  it("expose CLIENT_VIEWER en lecture seule et refuse l’absence de rôle client actif", async () => {
    const viewer = await createClientRecurringRepository(source({ roles: async () => ({ data: [{ membership_id: id(13), role_code: "CLIENT_VIEWER", revoked_at: null }], error: null }) })).load();
    expect(viewer).toMatchObject({ status: "success", value: { access: { activeRole: "CLIENT_VIEWER", canManage: false } } });
    await expect(createClientRecurringRepository(source({ roles: async () => ({ data: [], error: null }) })).load()).resolves.toEqual({ status: "error", reason: "FORBIDDEN" });
  });
  it("appelle le clonage avec les paramètres serveur explicites", async () => { const rpc = vi.fn().mockResolvedValue({ data: { outcome: "SERVICE_REQUEST_CLONED", request_id: id(10), request_version_id: id(11), status: "DRAFT" }, error: null }); const result = await createClientRecurringRepository(source({ rpc })).clone({ ...identity, sourceRequestId: id(2), desiredDate: "2026-11-01", reason: "Nouvelle commande" }); expect(result.status).toBe("success"); expect(rpc).toHaveBeenCalledWith("clone_service_request", { p_source_request_id: id(2), p_desired_date: "2026-11-01", p_change_reason: "Nouvelle commande", p_idempotency_key: id(8), p_correlation_id: id(9) }); });
  it("conserve la version optimiste pour une pause", async () => { const rpc = vi.fn().mockResolvedValue({ data: { outcome: "RECURRING_PLAN_PAUSED", plan_id: id(4), plan_version_id: id(12), status: "PAUSED", row_version: 3 }, error: null }); await createClientRecurringRepository(source({ rpc })).transition({ ...identity, planId: id(4), action: "PAUSE", expectedRowVersion: 2, reason: "Pause planifiée" }); expect(rpc).toHaveBeenCalledWith("transition_recurring_service_plan", expect.objectContaining({ p_action: "PAUSE", p_expected_row_version: 2 })); });
  it("vérifie les garanties sans invitation ni dépense de la génération", async () => { const rpc = vi.fn().mockResolvedValue({ data: { outcome: "RECURRING_REQUESTS_GENERATED", plan_id: id(4), plan_version_id: id(5), generated_count: 2, through_date: "2026-12-01", autonomous_invitations: false, autonomous_spend: false }, error: null }); const result = await createClientRecurringRepository(source({ rpc })).generate({ ...identity, planId: id(4), throughDate: "2026-12-01", maxOccurrences: 2 }); expect(result).toMatchObject({ status: "success", value: { generatedCount: 2, autonomousInvitations: false, autonomousSpend: false } }); });
  it("traduit les erreurs métier et rejette une réponse serveur ambiguë", async () => { const notEligible = await createClientRecurringRepository(source({ rpc: vi.fn().mockResolvedValue({ data: null, error: { message: "SERVICE_NOT_RECURRING_ELIGIBLE" } }) })).createPlan({ ...identity, templateRequestId: id(2), cadence: "MONTHLY", startsOn: "2026-10-01", endsOn: null, reason: "Cycle mensuel" }); expect(notEligible).toEqual({ status: "error", reason: "NOT_ELIGIBLE" }); const invalid = await createClientRecurringRepository(source({ rpc: vi.fn().mockResolvedValue({ data: { outcome: "OK" }, error: null }) })).clone({ ...identity, sourceRequestId: id(2), desiredDate: null, reason: "Nouveau besoin" }); expect(invalid).toEqual({ status: "error", reason: "INVALID_RESPONSE" }); });
});
