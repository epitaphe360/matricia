import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ rpc: vi.fn(), revalidate: vi.fn() }));
vi.mock("@/lib/client-portfolio/server-repository", () => ({ portfolioRpc: mocks.rpc }));
vi.mock("@/lib/client-portfolio/model", async () => import("../../../../lib/client-portfolio/model"));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidate }));
import { createProject, linkContract, recordAllocation, saveBudget, scheduleEvent } from "./actions";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
function form(values: Record<string, string>) { const result = new FormData(); for (const [key, value] of Object.entries(values)) result.set(key, value); return result; }
const base = { locale: "fr", idempotencyKey: id(1) };
const idle = { status:"idle" } as const;

describe("client portfolio actions", () => {
  beforeEach(() => { mocks.rpc.mockReset().mockResolvedValue({ status: "success", value: {} }); mocks.revalidate.mockReset(); });

  it("sends an exact minor-unit budget to the audited RPC", async () => {
    await expect(saveBudget(idle, form({ ...base, organizationId: id(2), fiscalYear: "2026", currency: "MAD", libraryId: "", siteId: id(3), projectId: "", amount: "1250,05", rationale: "Budget annuel validé", approve: "yes" }))).resolves.toEqual({ status: "success" });
    expect(mocks.rpc).toHaveBeenCalledWith("save_client_annual_budget", expect.objectContaining({ p_amount_minor: "125005", p_currency: "MAD", p_site_id: id(3), p_approve: true }));
    expect(mocks.revalidate).toHaveBeenCalledWith("/fr/client/portefeuille");
  });

  it("rejects a budget without scope before the database", async () => {
    await expect(saveBudget(idle, form({ ...base, organizationId: id(2), fiscalYear: "2026", currency: "MAD", libraryId: "", siteId: "", projectId: "", amount: "1.00", rationale: "Budget sans périmètre", approve: "no" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("rejects reversed project and calendar periods", async () => {
    await expect(createProject(idle, form({ ...base, organizationId: id(2), projectCode: "PROJET_1", siteId: "", nameFr: "Projet", nameAr: "مشروع", descriptionFr: "Description projet", descriptionAr: "وصف المشروع", startedOn: "2026-12-02", targetEndOn: "2026-12-01", changeReason: "Création initiale" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    await expect(scheduleEvent(idle, form({ ...base, organizationId: id(2), projectId: "", eventType: "CUSTOM", titleFr: "Échéance", titleAr: "موعد", startsAt: "2026-12-02T10:00", endsAt: "2026-12-02T09:00" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("requires a positive allocation and a SHA-256 evidence binding", async () => {
    await expect(recordAllocation(idle, form({ ...base, organizationId: id(2), costCenterId: id(3), budgetId: id(4), projectId: "", allocationType: "ACTUAL", amount: "0", evidenceHash: "bad" }))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("links a validated contract to a project through the audited command", async () => {
    await expect(linkContract(idle, form({ ...base, projectId:id(3), contractId:id(4) }))).resolves.toEqual({ status:"success" });
    expect(mocks.rpc).toHaveBeenCalledWith("link_contract_to_client_project", expect.objectContaining({ p_project_id:id(3), p_contract_id:id(4), p_idempotency_key:id(1) }));
  });
});
