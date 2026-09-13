import{beforeEach,describe,expect,it,vi}from"vitest";
const mocks=vi.hoisted(()=>({getUser:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({auth:{getUser:mocks.getUser},rpc:mocks.rpc})}));
vi.mock("@/lib/i18n/locale",()=>({isLocale:(value:string)=>value==="fr"||value==="ar"}));
vi.mock("@/lib/provider-missions/model",async()=>await import("../../../../lib/provider-missions/model"));
import{submitProviderDelivery,type DeliveryActionState}from"./actions";
const idle:DeliveryActionState={status:"idle"};
const deliverableId="11111111-1111-4111-8111-111111111111",key="22222222-2222-4222-8222-222222222222",digest="a".repeat(64);
function valid(){const f=new FormData();f.set("locale","fr");f.set("deliverableId",deliverableId);f.set("description","Rapport final validé");f.set("linksText","https://example.test/result");f.set("proofType","DOCUMENT");f.set("proofLocation","missions/reports/final.pdf");f.set("evidenceHash",digest);f.set("proofNote","Version signée");f.set("idempotencyKey",key);return f;}
beforeEach(()=>{mocks.getUser.mockReset().mockResolvedValue({data:{user:{id:"u"}}});mocks.rpc.mockReset().mockResolvedValue({data:{outcome:"DELIVERY_SUBMITTED"},error:null})});
describe("provider delivery action",()=>{
  it("preserves the real evidence digest for trusted scanning",async()=>{await expect(submitProviderDelivery(idle,valid())).resolves.toEqual({status:"success",outcome:"DELIVERY_SUBMITTED"});expect(mocks.rpc).toHaveBeenCalledWith("submit_delivery",expect.objectContaining({p_deliverable_id:deliverableId,p_proofs:[expect.objectContaining({evidence_hash:digest,storage_path:"missions/reports/final.pdf",url:null})]}))});
  it("rejects insecure evidence before RPC",async()=>{const f=valid();f.set("proofLocation","../secret.pdf");await expect(submitProviderDelivery(idle,f)).resolves.toEqual({status:"error",reason:"VALIDATION"});expect(mocks.rpc).not.toHaveBeenCalled()});
  it("rejects a malformed evidence digest",async()=>{const f=valid();f.set("evidenceHash","not-a-digest");await expect(submitProviderDelivery(idle,f)).resolves.toEqual({status:"error",reason:"VALIDATION"});expect(mocks.rpc).not.toHaveBeenCalled()});
});
