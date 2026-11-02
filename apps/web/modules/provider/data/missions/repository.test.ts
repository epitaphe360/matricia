import{beforeEach,describe,expect,it,vi}from"vitest";
const mocks=vi.hoisted(()=>({getUser:vi.fn(),from:vi.fn()}));
vi.mock("@/modules/shared/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({auth:{getUser:mocks.getUser},from:mocks.from})}));
import{loadProviderMissions}from"./repository";
function query(result:{data:unknown;error:unknown}){const chain:Record<string,unknown>={};for(const method of["select","eq","is","in","order","limit","range"])chain[method]=vi.fn(()=>chain);chain.maybeSingle=vi.fn(async()=>result);chain.then=(resolve:(v:unknown)=>unknown)=>resolve(result);return chain}
describe("provider mission repository",()=>{
 beforeEach(()=>{vi.clearAllMocks();mocks.getUser.mockResolvedValue({data:{user:{id:"11111111-1111-4111-8111-111111111111"}}})});
 it("does not query tenant data without authentication",async()=>{mocks.getUser.mockResolvedValue({data:{user:null}});await expect(loadProviderMissions("fr")).resolves.toEqual({status:"error",reason:"UNAUTHENTICATED"});expect(mocks.from).not.toHaveBeenCalled()});
 it("rejects an invalid provider organization identifier",async()=>{mocks.from.mockReturnValue(query({data:{organization_id:"foreign",organizations:{display_name:"Provider"}},error:null}));await expect(loadProviderMissions("ar")).resolves.toEqual({status:"error",reason:"QUERY_FAILED"});expect(mocks.from).toHaveBeenCalledTimes(1)});
 it("fails closed on a membership query error",async()=>{mocks.from.mockReturnValue(query({data:null,error:{code:"42501"}}));await expect(loadProviderMissions("fr")).resolves.toEqual({status:"error",reason:"QUERY_FAILED"})});
 it.each(["PROVIDER_ACCOUNTING","PROVIDER_SALES"])("keeps %s read-only while preserving authorized mission context",async role=>{
  const organizationId="22222222-2222-4222-8222-222222222222";
  mocks.from.mockImplementation((table:string)=>{const chain=query({data:table==="organization_memberships"?[{organization_id:organizationId,organizations:{display_name:"Provider"},organization_member_roles:[{role_code:role,revoked_at:null}]}]:[],error:null});
  chain.in=vi.fn((column:string,values:string[])=>{if(column==="organization_member_roles.role_code")expect(values).toContain(role);return chain});return chain;});
  const result=await loadProviderMissions("fr",organizationId);expect(result.status).toBe("success");if(result.status!=="success")return;expect(result.dashboard.organizationId).toBe(organizationId);expect(result.dashboard.canOperate).toBe(false);expect(result.dashboard.canManageAssignments).toBe(false);
 });
});
