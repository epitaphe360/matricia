import { beforeEach,describe,expect,it,vi } from "vitest";
const mocks=vi.hoisted(()=>({getUser:vi.fn(),rpc:vi.fn()}));
vi.mock("@/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({auth:{getUser:mocks.getUser},rpc:mocks.rpc})}));
vi.mock("@/lib/i18n/locale",()=>({isLocale:(value:string)=>value==="fr"||value==="ar"}));
vi.mock("@/lib/provider-qualification/model",async()=>await import("../../../../lib/provider-qualification/model"));
import { declareProviderCapacity,requestProviderService,submitProviderProfile,type ProviderActionState } from "./actions";
const idle:ProviderActionState={status:"idle"};const org="11111111-1111-4111-8111-111111111111";const service="22222222-2222-4222-8222-222222222222";const key="33333333-3333-4333-8333-333333333333";
function base(){const form=new FormData();form.set("locale","fr");form.set("organizationId",org);form.set("idempotencyKey",key);return form}
beforeEach(()=>{mocks.getUser.mockReset().mockResolvedValue({data:{user:{id:"user-1"}}});mocks.rpc.mockReset().mockResolvedValue({data:{outcome:"PROVIDER_OPERATION_RECORDED",command_id:"44444444-4444-4444-8444-444444444444"},error:null})});
describe("provider qualification actions",()=>{
 it("never calls RPC for invalid profile",async()=>{const form=base();form.set("expectedRowVersion","0");form.set("activitySummary","court");form.set("teamSize","0");form.set("yearsExperience","-1");await expect(submitProviderProfile(idle,form)).resolves.toEqual({status:"error",reason:"VALIDATION"});expect(mocks.rpc).not.toHaveBeenCalled()});
 it("maps the service request to RPC 062",async()=>{const form=base();form.set("serviceId",service);await expect(requestProviderService(idle,form)).resolves.toEqual({status:"success",outcome:"PROVIDER_OPERATION_RECORDED"});expect(mocks.rpc).toHaveBeenCalledWith("request_provider_service",{p_provider_organization_id:org,p_service_id:service,p_idempotency_key:key})});
 it("enforces PAUSED capacity without units",async()=>{const form=base();form.set("serviceId",service);form.set("capacityStatus","PAUSED");form.set("availableUnits","12");form.set("leadTimeDays","4");form.set("reason","Congé planifié");await expect(declareProviderCapacity(idle,form)).resolves.toEqual({status:"success",outcome:"PROVIDER_OPERATION_RECORDED"});expect(mocks.rpc).toHaveBeenCalledWith("declare_provider_capacity",expect.objectContaining({p_capacity_status:"PAUSED",p_available_units:null}))});
 it("does not invoke business RPC without session",async()=>{mocks.getUser.mockResolvedValueOnce({data:{user:null}});const form=base();form.set("serviceId",service);await expect(requestProviderService(idle,form)).resolves.toEqual({status:"error",reason:"UNAUTHENTICATED"});expect(mocks.rpc).not.toHaveBeenCalled()});
});
