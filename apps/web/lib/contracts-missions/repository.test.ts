import{beforeEach,describe,expect,it,vi}from"vitest";
const mocks=vi.hoisted(()=>({getUser:vi.fn(),from:vi.fn()}));
vi.mock("@/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({auth:{getUser:mocks.getUser},from:mocks.from})}));
import{loadContractMissions}from"./repository";
function query(result:{data:unknown;error:unknown}){const chain:Record<string,unknown>={};for(const method of["select","eq","is","in","order","limit"])chain[method]=vi.fn(()=>chain);chain.maybeSingle=vi.fn(async()=>result);chain.then=(resolve:(v:unknown)=>unknown)=>resolve(result);return chain}
describe("client contract mission repository",()=>{
 beforeEach(()=>{vi.clearAllMocks();mocks.getUser.mockResolvedValue({data:{user:{id:"11111111-1111-4111-8111-111111111111"}}})});
 it("fails before every query when the session is missing",async()=>{mocks.getUser.mockResolvedValue({data:{user:null}});await expect(loadContractMissions("fr")).resolves.toEqual({status:"error",reason:"UNAUTHENTICATED"});expect(mocks.from).not.toHaveBeenCalled()});
 it("rejects a malformed membership response instead of widening tenant scope",async()=>{mocks.from.mockReturnValue(query({data:{organization_id:"not-a-uuid",organizations:{display_name:"Client"}},error:null}));await expect(loadContractMissions("fr")).resolves.toEqual({status:"error",reason:"INVALID_RESPONSE"});expect(mocks.from).toHaveBeenCalledTimes(1)});
 it("fails closed on a membership query error",async()=>{mocks.from.mockReturnValue(query({data:null,error:{code:"42501"}}));await expect(loadContractMissions("ar")).resolves.toEqual({status:"error",reason:"QUERY_FAILED"})});
});
