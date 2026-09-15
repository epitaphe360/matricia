import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ create: vi.fn(), compare: vi.fn(), context: vi.fn(), createFromOpportunity:vi.fn(), revalidate: vi.fn() }));
vi.mock("../../../../lib/client-rfq/server-repository", () => ({ createServerClientRfqRepository: async () => ({ create: mocks.create, compare: mocks.compare }) }));
vi.mock("./opportunity-context", () => ({ loadOpportunityRequestContext: mocks.context, createRequestFromOpportunity:mocks.createFromOpportunity }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
vi.mock("node:crypto", () => ({ randomUUID: () => "99999999-9999-4999-8999-999999999999" }));
import { compareQuotesAction, createRequestAction, type ActionState, type ComparisonState } from "./actions";

const uid = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
const context = { opportunityId: uid(2), organizationId: uid(3), libraryId: uid(4), serviceId: uid(5), questionnaireVersionId: uid(6), catalogSnapshotHash: "a".repeat(64), questionnaireSnapshotHash: "b".repeat(64), existingRequestId: null };
function createForm(overrides: Record<string, string> = {}) { const form = new FormData(); const values = { locale: "fr", opportunityId: uid(2), organizationId: uid(3), description: "Une description suffisamment détaillée", urgency: "NORMAL", desiredDate: "2026-10-01", budget: "1 250,50", currency: "MAD", regionCode: "MA-CASABLANCA", ...overrides }; for (const [key, value] of Object.entries(values)) form.set(key, value); return form; }

describe("actions RFQ Client", () => {
  beforeEach(() => { vi.clearAllMocks(); mocks.context.mockResolvedValue(context); });

  it("valide les champs métier avant tout accès au contexte", async () => {
    await expect(createRequestAction({ status: "idle" } as ActionState, createForm({ description: "court" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.context).not.toHaveBeenCalled(); expect(mocks.create).not.toHaveBeenCalled();
  });

  it("dérive versions et empreintes côté serveur et convertit le budget exactement", async () => {
    mocks.createFromOpportunity.mockResolvedValue({ requestId: uid(7), status: "DRAFT" });
    await expect(createRequestAction({ status: "idle" }, createForm())).resolves.toEqual({ status: "success", message: "CREATED", requestId: uid(7) });
    expect(mocks.context).toHaveBeenCalledWith(uid(2), uid(3));
    expect(mocks.createFromOpportunity).toHaveBeenCalledWith(expect.objectContaining({ opportunityId:uid(2), budgetMinor: "125050", correlationId: "99999999-9999-4999-8999-999999999999" }));
    expect(mocks.revalidate).toHaveBeenCalledWith("/fr/client/demandes");
  });

  it("échoue honnêtement si la priorité n’est plus autorisée", async () => {
    mocks.context.mockResolvedValue(null);
    await expect(createRequestAction({ status: "idle" }, createForm())).resolves.toEqual({ status: "error", reason: "CONTEXT_REQUIRED" });
    expect(mocks.createFromOpportunity).not.toHaveBeenCalled();
  });

  it("retourne uniquement les lignes normalisées", async () => {
    mocks.compare.mockResolvedValue({ status: "success", value: { snapshotId: uid(2), currency: "MAD", rows: [] } });
    const form = new FormData(); form.set("locale", "ar"); form.set("idempotencyKey", uid(1)); form.set("rfqId", uid(3));
    await expect(compareQuotesAction({ status: "idle" } as ComparisonState, form)).resolves.toEqual({ status: "success", snapshotId: uid(2), currency: "MAD", rows: [] });
  });
});
