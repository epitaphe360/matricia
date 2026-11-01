import {beforeEach,describe,expect,it,vi} from "vitest";
const {rpc,getUser}=vi.hoisted(()=>({rpc:vi.fn(),getUser:vi.fn()}));
vi.mock("@/modules/shared/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({auth:{getUser},rpc})}));
import {loadMoroccoTaxDashboard} from "./repository";
describe("central fiscal dashboard",()=>{
 beforeEach(()=>{vi.clearAllMocks();getUser.mockResolvedValue({data:{user:{id:"11111111-1111-4111-8111-111111111111"}}});});
 it("loads the actual platform catalogue without a tenant query",async()=>{
  rpc.mockImplementation(async(name:string)=>name==="get_morocco_tax_context_v1"?{data:{kind:"PLATFORM"},error:null}:{data:{categories:[],rules:[]},error:null});
  expect(await loadMoroccoTaxDashboard()).toEqual({status:"success",dashboard:{context:{kind:"PLATFORM"},categories:[],rules:[]}});
  expect(rpc.mock.calls.map(call=>call[0])).toEqual(["get_morocco_tax_context_v1","list_morocco_tax_rules"]);
 });
 it("does not invent an organization when platform authorization is denied",async()=>{
  rpc.mockResolvedValue({data:null,error:{code:"42501",message:"MOROCCO_TAX_ADMIN_AAL2_REQUIRED"}});
  expect(await loadMoroccoTaxDashboard()).toEqual({status:"error",reason:"AAL2_REQUIRED"});
  expect(rpc).toHaveBeenCalledTimes(1);
 });
 it("rejects a hybrid platform and tenant context",async()=>{
  rpc.mockResolvedValue({data:{kind:"PLATFORM",organizationId:"11111111-1111-4111-8111-111111111111"},error:null});
  expect(await loadMoroccoTaxDashboard()).toEqual({status:"error",reason:"INVALID_RESPONSE"});
  expect(rpc).toHaveBeenCalledTimes(1);
 });
});
