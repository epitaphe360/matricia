import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn(), from: vi.fn(), revalidatePath: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc, from: mocks.from }) }));
vi.mock("@/lib/provider-quotes/model", async () => import("../../../../lib/provider-quotes/model"));
import { decideInvitation, saveQuoteRevision, submitQuote, type QuoteActionState } from "./actions";

const idle: QuoteActionState = { status: "idle" };
const ids = { invitation: "11111111-1111-4111-8111-111111111111", tax: "22222222-2222-4222-8222-222222222222", idempotency: "33333333-3333-4333-8333-333333333333", correlation: "44444444-4444-4444-8444-444444444444", requestVersion: "55555555-5555-4555-8555-555555555555", quote: "66666666-6666-4666-8666-666666666666", quoteVersion: "77777777-7777-4777-8777-777777777777" };
function query(data: unknown, error: unknown = null) { const value: Record<string, unknown> = {}; for (const method of ["select", "eq", "lte", "or"]) value[method] = vi.fn(() => value); value.maybeSingle = vi.fn(async () => ({ data, error })); return value; }
function validForm() {
  const form = new FormData();
  const values = { locale:"fr",rfqProviderId:ids.invitation,currency:"USD",solutionFr:"Solution contrôlée",solutionAr:"",deliverables:"Audit\nRapport",inclusions:"",exclusions:"",prerequisites:"",warrantyFr:"Douze mois",warrantyAr:"",correctionTermsFr:"Correction incluse",correctionTermsAr:"",proposedStartDate:"2026-10-01",durationDays:"10",validUntil:"2027-01-01T00:00",lineLabelFr:"Forfait",lineLabelAr:"",quantity:"1.2500",unitCode:"forfait",unitPriceMinor:"900719925474099300",taxRuleVersionId:ids.tax,itemKind:"ONE_TIME",recurrenceInterval:"",changeReason:"Première version",idempotencyKey:ids.idempotency,correlationId:ids.correlation };
  for (const [key, value] of Object.entries(values)) form.set(key, value);
  return form;
}
function form(values: Record<string, string>) { const result = new FormData(); for (const [key, value] of Object.entries(values)) result.set(key, value); return result; }

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "provider" } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "CREATED" }, error: null });
  mocks.from.mockReset().mockImplementation((table: string) => table === "rfq_providers" ? query({ rfqs: { request_version_id: ids.requestVersion } }) : table === "service_request_versions" ? query({ currency_code: "USD", required_quote_data: { tax_category_code: "STANDARD_SERVICE" } }) : query({ id: ids.tax }));
  mocks.revalidatePath.mockReset();
});

describe("provider quote actions", () => {
  it("transmet les chaînes financières exactes et la devise persistée", async () => {
    await expect(saveQuoteRevision(idle, validForm())).resolves.toEqual({ status: "success", outcome: "QUOTE_REVISION_CREATED" });
    expect(mocks.rpc).toHaveBeenCalledWith("create_quote_revision", expect.objectContaining({ p_payload: expect.objectContaining({ currency: "USD", items: [expect.objectContaining({ quantity: "1.2500", unit_price_minor: "900719925474099300" })] }) }));
  });

  it("refuse une devise altérée avant la mutation", async () => { const value=validForm();value.set("currency","EUR");await expect(saveQuoteRevision(idle,value)).resolves.toEqual({status:"error",reason:"VALIDATION"});expect(mocks.rpc).not.toHaveBeenCalled(); });
  it("refuse un montant décimal avant tout appel RPC", async () => { const value=validForm();value.set("unitPriceMinor","10.5");await expect(saveQuoteRevision(idle,value)).resolves.toEqual({status:"error",reason:"VALIDATION"});expect(mocks.rpc).not.toHaveBeenCalled(); });
  it("refuse une session absente", async () => { mocks.getUser.mockResolvedValue({data:{user:null}});await expect(saveQuoteRevision(idle,validForm())).resolves.toEqual({status:"error",reason:"UNAUTHENTICATED"});expect(mocks.rpc).not.toHaveBeenCalled(); });

  it("envoie une décision d’invitation versionnée", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "RFQ_INVITATION_ACCEPTED" }, error: null });
    await expect(decideInvitation(idle, form({ locale:"fr",invitationId:ids.invitation,decision:"ACCEPT",reason:"",rowVersion:"2",idempotencyKey:ids.idempotency,correlationId:ids.correlation }))).resolves.toEqual({ status:"success",outcome:"RFQ_INVITATION_ACCEPTED" });
    expect(mocks.rpc).toHaveBeenCalledWith("respond_to_rfq_invitation", { p_rfq_provider_id:ids.invitation,p_decision:"ACCEPT",p_reason:null,p_expected_row_version:2,p_idempotency_key:ids.idempotency,p_correlation_id:ids.correlation });
  });

  it("soumet uniquement la version explicite du devis", async () => {
    await expect(submitQuote(idle, form({ locale:"ar",quoteId:ids.quote,quoteVersionId:ids.quoteVersion,idempotencyKey:ids.idempotency,correlationId:ids.correlation }))).resolves.toEqual({ status:"success",outcome:"QUOTE_SUBMITTED" });
    expect(mocks.rpc).toHaveBeenCalledWith("submit_quote", { p_quote_id:ids.quote,p_expected_version_id:ids.quoteVersion,p_idempotency_key:ids.idempotency,p_correlation_id:ids.correlation });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/ar/sous-traitant/devis");
  });
});
