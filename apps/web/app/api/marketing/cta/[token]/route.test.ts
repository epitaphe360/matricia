import{beforeEach,describe,expect,it,vi}from"vitest";
import{MARKETING_TOUCH_COOKIE,verifyMarketingTouch}from"@/modules/shared/lib/marketing-autopilot/funnel-touch";
const mocks=vi.hoisted(()=>({rpc:vi.fn()}));
vi.mock("@/modules/shared/lib/supabase/admin",()=>({getSupabaseAdminClient:()=>({rpc:mocks.rpc})}));
import{GET}from"./route";
const token="a".repeat(128),request=(cookie?:string)=>new Request(`https://matricia.ma/api/marketing/cta/${token}`,{headers:{"user-agent":"browser","x-forwarded-for":"192.0.2.1","x-request-id":"req-1",...(cookie?{cookie}:{})}});
const resolved={outcome:"MARKETING_CTA_RESOLVED",organization_id:"11111111-1111-4111-8111-111111111111",campaign_id:"22222222-2222-4222-8222-222222222222",content_id:"33333333-3333-4333-8333-333333333333",service_id:"44444444-4444-4444-8444-444444444444",destination_url:"https://matricia.ma/diagnostic?campaign_id=2&utm_source=linkedin&utm_medium=social"};
describe("public marketing CTA",()=>{
  beforeEach(()=>{process.env.MARKETING_CTA_SIGNING_SECRET="s".repeat(32);delete process.env.VERCEL;mocks.rpc.mockReset()});
  it("resolves a signed opaque token and issues a signed visitor cookie",async()=>{mocks.rpc.mockResolvedValue({error:null,data:resolved});const response=await GET(request(),{params:Promise.resolve({token})});expect(response.status).toBe(302);expect(response.headers.get("location")).toContain("/diagnostic");expect(response.headers.get("set-cookie")).toContain("HttpOnly");expect(mocks.rpc).toHaveBeenCalledWith("resolve_marketing_cta_v1",expect.objectContaining({p_token:token,p_visitor_hash:expect.stringMatching(/^[0-9a-f]{64}$/),p_idempotency_key:expect.stringMatching(/^[0-9a-f]{64}$/)}))});
  it("sets a signed site-wide touch cookie and records the click for the funnel",async()=>{
    mocks.rpc.mockResolvedValue({error:null,data:resolved});
    const response=await GET(request(),{params:Promise.resolve({token})});
    const cookies=response.headers.getSetCookie();
    expect(cookies).toHaveLength(2);
    const touchCookie=cookies.find(value=>value.startsWith(`${MARKETING_TOUCH_COOKIE}=`))??"";
    expect(touchCookie).toMatch(/Path=\/;/);expect(touchCookie).toContain("HttpOnly");expect(touchCookie).toContain("Secure");expect(touchCookie).toContain("SameSite=Lax");
    const touch=verifyMarketingTouch(touchCookie.split(";")[0]!.slice(MARKETING_TOUCH_COOKIE.length+1),"s".repeat(32));
    expect(touch).toMatchObject({organizationId:resolved.organization_id,campaignId:resolved.campaign_id,contentId:resolved.content_id,source:"linkedin",medium:"social"});
    expect(mocks.rpc).toHaveBeenCalledWith("ingest_marketing_attribution_event_v1",expect.objectContaining({p_event_type:"CTA_CLICKED",p_campaign_id:resolved.campaign_id,p_metadata:{},p_idempotency_key:expect.stringMatching(/^cta-click:[0-9a-f]{64}$/)}));
  });
  it("still redirects when click attribution is refused",async()=>{mocks.rpc.mockResolvedValueOnce({error:null,data:resolved}).mockResolvedValueOnce({error:{message:"CONSENT"},data:null});expect((await GET(request(),{params:Promise.resolve({token})})).status).toBe(302)});
  it("fails closed without a signing secret",async()=>{delete process.env.MARKETING_CTA_SIGNING_SECRET;expect((await GET(request(),{params:Promise.resolve({token})})).status).toBe(503);expect(mocks.rpc).not.toHaveBeenCalled()});
});
