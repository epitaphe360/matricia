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
 it("shows the completed mission's V1 snapshot while a signed V2 has not been executed",async()=>{
  const id=(n:number)=>`f1000000-0000-4000-8000-${String(n).padStart(12,"0")}`,org=id(1),contract=id(2),mission=id(3),v1=id(4),v2=id(5);
  const tables:Record<string,unknown[]>={organization_memberships:[{organization_id:org,organizations:{display_name:"Provider"},organization_member_roles:[{role_code:"PROVIDER_VIEWER",revoked_at:null}]}],missions:[{id:mission,contract_id:contract,contract_version_id:v1,scope_reconciliation_required:false,status:"COMPLETED",started_at:null,completed_at:"2026-11-01T12:00:00Z"}],contracts:[{id:contract,current_version:2}],contract_versions:[{id:v1,contract_id:contract,version:1,price_minor:"12000",currency:"MAD",content_hash:"a".repeat(64),request_snapshot:{description:"Mission initiale achevée"}},{id:v2,contract_id:contract,version:2,price_minor:"14000",currency:"MAD",content_hash:"b".repeat(64),request_snapshot:{description:"Périmètre signé non exécuté"}}]};
  mocks.from.mockImplementation((table:string)=>query({data:tables[table]??[],error:null}));
  const result=await loadProviderMissions("fr",org);expect(result.status).toBe("success");if(result.status!=="success")return;expect(result.dashboard.missions[0]?.contract).toMatchObject({currentVersion:1,priceMinor:"12000",contentHash:"a".repeat(64)});expect(result.dashboard.missions[0]?.title).toBe("Mission initiale achevée");
 });
});
