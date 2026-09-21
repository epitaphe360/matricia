import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ create: vi.fn(), compare: vi.fn(), select: vi.fn(), detail: vi.fn(), context: vi.fn(), createFromOpportunity:vi.fn(), needContext: vi.fn(), createFromNeed: vi.fn(), revalidate: vi.fn() }));
vi.mock("@/modules/client/data/rfq/server-repository", () => ({ createServerClientRfqRepository: async () => ({ create: mocks.create, compare: mocks.compare, select: mocks.select, detail: mocks.detail }) }));
vi.mock("./opportunity-context", () => ({ loadOpportunityRequestContext: mocks.context, createRequestFromOpportunity:mocks.createFromOpportunity }));
vi.mock("./need-context", () => ({ loadNeedRequestContext: mocks.needContext, createRequestFromNeed: mocks.createFromNeed }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
vi.mock("node:crypto", () => ({ randomUUID: () => "99999999-9999-4999-8999-999999999999" }));
import { compareQuotesAction, createRequestAction, selectQuoteAction, type ActionState, type ComparisonState } from "./actions";

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
    expect(mocks.createFromOpportunity).toHaveBeenCalledWith(expect.objectContaining({ opportunityId:uid(2), budgetMinor: "125050", siteId: null, correlationId: "99999999-9999-4999-8999-999999999999" }));
    expect(mocks.revalidate).toHaveBeenCalledWith("/fr/client/demandes");
  });

  it("transmet le site Client vers la conversion atomique", async () => {
    mocks.createFromOpportunity.mockResolvedValue({ requestId: uid(7), status: "DRAFT" });
    await expect(createRequestAction({ status: "idle" }, createForm({ siteId: uid(4) }))).resolves.toEqual({ status: "success", message: "CREATED", requestId: uid(7) });
    expect(mocks.createFromOpportunity).toHaveBeenCalledWith(expect.objectContaining({ siteId: uid(4) }));
  });

  it("échoue honnêtement si la priorité n’est plus autorisée", async () => {
    mocks.context.mockResolvedValue(null);
    await expect(createRequestAction({ status: "idle" }, createForm())).resolves.toEqual({ status: "error", reason: "CONTEXT_REQUIRED" });
    expect(mocks.createFromOpportunity).not.toHaveBeenCalled();
  });

  it("convertit un besoin confirmé sans ouvrir la consultation", async () => {
    mocks.needContext.mockResolvedValue({ intakeId: uid(8), serviceCode: "IT-AUDIT-SI", organizationId: uid(3), existingRequestId: null });
    mocks.createFromNeed.mockResolvedValue({ requestId: uid(9), status: "DRAFT" });
    const form = createForm();
    form.delete("opportunityId");
    form.set("intakeId", uid(8));
    form.set("serviceCode", "IT-AUDIT-SI");
    await expect(createRequestAction({ status: "idle" }, form)).resolves.toEqual({ status: "success", message: "CREATED", requestId: uid(9) });
    expect(mocks.needContext).toHaveBeenCalledWith(uid(8), "IT-AUDIT-SI", uid(3));
    expect(mocks.createFromNeed).toHaveBeenCalledWith(expect.objectContaining({ intakeId: uid(8), serviceCode: "IT-AUDIT-SI", budgetMinor: "125050", siteId: null }));
    expect(mocks.createFromOpportunity).not.toHaveBeenCalled();
  });

  it("refuse une création non habilitée sans révalidation", async () => {
    mocks.createFromOpportunity.mockResolvedValue({ forbidden: true });
    await expect(createRequestAction({ status: "idle" }, createForm())).resolves.toEqual({ status: "error", reason: "FORBIDDEN" });
    expect(mocks.revalidate).not.toHaveBeenCalled();
  });

  it("retourne uniquement les lignes normalisées", async () => {
    mocks.compare.mockResolvedValue({ status: "success", value: { snapshotId: uid(2), currency: "MAD", rows: [] } });
    const form = new FormData(); form.set("locale", "ar"); form.set("idempotencyKey", uid(1)); form.set("rfqId", uid(3)); form.set("requestId", uid(4));
    await expect(compareQuotesAction({ status: "idle" } as ComparisonState, form)).resolves.toEqual({ status: "success", snapshotId: uid(2), currency: "MAD", rows: [] });
  });

  it("refuse une sélection sans motif ni confirmation", async () => {
    const form = new FormData();
    form.set("locale", "fr"); form.set("idempotencyKey", uid(1)); form.set("requestId", uid(4)); form.set("quoteId", uid(5)); form.set("quoteVersionId", uid(6)); form.set("comparisonSnapshotId", uid(7));
    await expect(selectQuoteAction({ status: "idle" } as ActionState, form)).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.select).not.toHaveBeenCalled();
  });

  it("sélectionne un devis complet après confirmation humaine", async () => {
    mocks.detail.mockResolvedValue({ status: "success", value: { rfqId: uid(3), canManage: true } });
    mocks.select.mockResolvedValue({ status: "success", value: { quoteId: uid(5), rfqId: uid(3) } });
    const form = new FormData();
    form.set("locale", "fr"); form.set("idempotencyKey", uid(1)); form.set("requestId", uid(4)); form.set("quoteId", uid(5)); form.set("quoteVersionId", uid(6)); form.set("comparisonSnapshotId", uid(7)); form.set("selectionReason", "Offre la plus adaptée au délai"); form.set("confirmSelection", "on");
    await expect(selectQuoteAction({ status: "idle" }, form)).resolves.toEqual({ status: "success", message: "SELECTED", requestId: uid(4) });
    expect(mocks.select).toHaveBeenCalledWith(expect.objectContaining({ selectionReason: "Offre la plus adaptée au délai", comparisonSnapshotId: uid(7) }));
  });
});
