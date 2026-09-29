import { createHmac,randomBytes,randomUUID,timingSafeEqual } from "node:crypto";
import { isIP } from "node:net";
import { z } from "zod";
import { getSupabaseAdminClient } from "@/modules/shared/lib/supabase/admin";
import { MARKETING_TOUCH_TTL_SECONDS, marketingChannel, marketingTouchCookie, marketingTouchVisitorHash, signMarketingTouch } from "@/modules/shared/lib/marketing-autopilot/funnel-touch";

export const dynamic = "force-dynamic";
const tokenSchema=z.string().regex(/^[0-9a-f]{128}$/);
const resultSchema=z.object({outcome:z.literal("MARKETING_CTA_RESOLVED"),organization_id:z.string().uuid(),campaign_id:z.string().uuid(),content_id:z.string().uuid(),service_id:z.string().uuid(),destination_url:z.string().url().refine((value)=>value.startsWith("https://"))}).strict();
const noStore={"cache-control":"no-store, private","referrer-policy":"no-referrer","x-content-type-options":"nosniff"} as const;

const cookieName="matricia_cta_visitor";
function signedVisitor(request:Request,secret:string){
  const raw=request.headers.get("cookie")?.split(";").map((value)=>value.trim()).find((value)=>value.startsWith(`${cookieName}=`))?.slice(cookieName.length+1);
  if(raw){const [nonce,expiry,signature]=raw.split(".");if(nonce&&/^[0-9a-f]{32}$/.test(nonce)&&expiry&&/^\d{10,13}$/.test(expiry)&&signature&&/^[0-9a-f]{64}$/.test(signature)&&Number(expiry)>Date.now()){const expected=createHmac("sha256",secret).update(`${nonce}.${expiry}`).digest();const presented=Buffer.from(signature,"hex");if(expected.length===presented.length&&timingSafeEqual(expected,presented))return{nonce,cookie:null}}}
  const nonce=randomBytes(16).toString("hex"),expiry=String(Date.now()+86_400_000),signature=createHmac("sha256",secret).update(`${nonce}.${expiry}`).digest("hex");return{nonce,cookie:`${cookieName}=${nonce}.${expiry}.${signature}; Max-Age=86400; Path=/api/marketing/cta/; Secure; HttpOnly; SameSite=Lax`};
}
function visitorHash(request:Request,secret:string,nonce:string){
  const platformIp=process.env.VERCEL==="1"?(request.headers.get("x-vercel-forwarded-for")?.split(",")[0]?.trim()??""):"";
  const trustedIp=isIP(platformIp)?platformIp:"platform-unavailable";
  const agent=(request.headers.get("user-agent")??"unknown").slice(0,256);
  const day=new Date().toISOString().slice(0,10);
  return createHmac("sha256",secret).update(`${day}\0${nonce}\0${trustedIp}\0${agent}`).digest("hex");
}

export async function GET(request:Request,{params}:{params:Promise<{token:string}>}){
  const secret=process.env.MARKETING_CTA_SIGNING_SECRET??"";
  if(secret.length<32)return Response.json({code:"CTA_UNAVAILABLE"},{status:503,headers:noStore});
  const parsed=tokenSchema.safeParse((await params).token);if(!parsed.success)return Response.json({code:"CTA_NOT_FOUND"},{status:404,headers:noStore});
  const visitor=signedVisitor(request,secret),idempotencyKey=createHmac("sha256",secret).update(`${parsed.data}\0${randomUUID()}`).digest("hex");
  const result=await getSupabaseAdminClient().rpc("resolve_marketing_cta_v1",{p_token:parsed.data,p_visitor_hash:visitorHash(request,secret,visitor.nonce),p_idempotency_key:idempotencyKey});
  if(result.error)return Response.json({code:result.error.message.includes("RATE_LIMITED")?"CTA_RATE_LIMITED":"CTA_NOT_FOUND"},{status:result.error.message.includes("RATE_LIMITED")?429:404,headers:noStore});
  const resolved=resultSchema.safeParse(result.data);if(!resolved.success)return Response.json({code:"CTA_UNAVAILABLE"},{status:503,headers:noStore});
  const destination=new URL(resolved.data.destination_url),source=new URL(request.url);
  if(destination.protocol!=="https:"||(destination.hostname===source.hostname&&destination.pathname.startsWith("/api/marketing/cta/")))return Response.json({code:"CTA_UNAVAILABLE"},{status:503,headers:noStore});
  const touch={organizationId:resolved.data.organization_id,campaignId:resolved.data.campaign_id,contentId:resolved.data.content_id,nonce:visitor.nonce,source:marketingChannel(destination.searchParams.get("utm_source"),"matricia_cta"),medium:marketingChannel(destination.searchParams.get("utm_medium"),"social"),expiresAt:Date.now()+MARKETING_TOUCH_TTL_SECONDS*1000};
  await getSupabaseAdminClient().rpc("ingest_marketing_attribution_event_v1",{p_organization_id:touch.organizationId,p_campaign_id:touch.campaignId,p_content_id:touch.contentId,p_event_type:"CTA_CLICKED",p_source:touch.source,p_medium:touch.medium,p_visitor_hash:marketingTouchVisitorHash(touch.nonce,secret),p_economic_value_minor:null,p_occurred_at:new Date().toISOString(),p_metadata:{},p_idempotency_key:`cta-click:${idempotencyKey}`}).then(()=>undefined,()=>undefined);
  const headers=new Headers({...noStore,location:destination.toString()});
  if(visitor.cookie)headers.append("set-cookie",visitor.cookie);
  headers.append("set-cookie",marketingTouchCookie(signMarketingTouch(touch,secret)));
  return new Response(null,{status:302,headers});
}
