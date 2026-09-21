import { randomUUID } from "node:crypto";
import { createPaymentGateway, PaymentGatewayError } from "@matricia/infrastructure";
import { NextResponse } from "next/server";
import { z } from "zod";
import { getPaymentRuntimeConfig, getServerEnvironment } from "@/modules/shared/lib/env";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

const inputSchema=z.object({organizationId:z.string().uuid(),planVersionId:z.string().uuid(),billingInterval:z.enum(["MONTHLY","ANNUAL"]),idempotencyKey:z.string().uuid(),locale:z.enum(["fr","ar"])});
const planSchema=z.object({currency:z.string().regex(/^[A-Z]{3}$/u),monthly_price_minor:z.string().regex(/^\d+$/u),annual_price_minor:z.string().regex(/^\d+$/u)});
const maximumBodyBytes=32_768;

export async function POST(request:Request){
  let environment: ReturnType<typeof getServerEnvironment>;
  let gateway: ReturnType<typeof createPaymentGateway>;
  try {
    environment=getServerEnvironment();
    gateway=createPaymentGateway(getPaymentRuntimeConfig());
  } catch {
    return NextResponse.json({error:"PAYMENT_CONFIGURATION_UNAVAILABLE"},{status:503});
  }
  if(!sameOrigin(request,environment.NEXT_PUBLIC_APP_URL))return NextResponse.json({error:"REQUEST_ORIGIN_DENIED"},{status:403});
  const length=Number(request.headers.get("content-length")??"0");
  if(!Number.isSafeInteger(length)||length>maximumBodyBytes)return NextResponse.json({error:"REQUEST_TOO_LARGE"},{status:413});
  let body:unknown;try{const raw=await request.text();if(new TextEncoder().encode(raw).byteLength>maximumBodyBytes)return NextResponse.json({error:"REQUEST_TOO_LARGE"},{status:413});body=JSON.parse(raw);}catch{return NextResponse.json({error:"INVALID_REQUEST"},{status:400});}
  const parsed=inputSchema.safeParse(body);if(!parsed.success)return NextResponse.json({error:"INVALID_REQUEST"},{status:400});
  const client=await getSupabaseServerClient();const{data:auth}=await client.auth.getUser();if(!auth.user)return NextResponse.json({error:"UNAUTHENTICATED"},{status:401});
  const planResult=await client.from("subscription_plan_versions").select("currency,monthly_price_minor::text,annual_price_minor::text").eq("id",parsed.data.planVersionId).eq("status","ACTIVE").lte("valid_from",new Date().toISOString().slice(0,10)).or(`valid_to.is.null,valid_to.gte.${new Date().toISOString().slice(0,10)}`).maybeSingle();
  if(planResult.error||!planResult.data)return NextResponse.json({error:"PLAN_UNAVAILABLE"},{status:422});
  const plan=planSchema.safeParse(planResult.data);if(!plan.success)return NextResponse.json({error:"PLAN_UNAVAILABLE"},{status:422});
  const amountMinor=parsed.data.billingInterval==="MONTHLY"?plan.data.monthly_price_minor:plan.data.annual_price_minor;
  try{
    const intent=await gateway.createIntent({organizationId:parsed.data.organizationId,planVersionId:parsed.data.planVersionId,billingInterval:parsed.data.billingInterval,amountMinor,currency:plan.data.currency,idempotencyKey:parsed.data.idempotencyKey,returnUrl:new URL(`/${parsed.data.locale}/client/abonnement?payment=pending`,environment.NEXT_PUBLIC_APP_URL).toString()});
    const{data,error}=await client.rpc("register_subscription_payment_intent",{p_organization_id:parsed.data.organizationId,p_plan_version_id:parsed.data.planVersionId,p_billing_interval:parsed.data.billingInterval,p_gateway:intent.gateway,p_provider_intent_id:intent.providerIntentId,p_amount_minor:intent.amountMinor,p_currency:intent.currency,p_idempotency_key:parsed.data.idempotencyKey,p_correlation_id:randomUUID()});
    if(error)return NextResponse.json({error:error.code==="42501"?"FORBIDDEN":"PAYMENT_INTENT_UNAVAILABLE"},{status:error.code==="42501"?403:409});
    const paymentIntentId=isRecord(data)&&typeof data.payment_intent_id==="string"?data.payment_intent_id:null;
    if(!paymentIntentId)return NextResponse.json({error:"PAYMENT_INTENT_UNAVAILABLE"},{status:502});
    return NextResponse.json({paymentIntentId,providerIntentId:intent.providerIntentId,gateway:intent.gateway,status:intent.status,amountMinor:intent.amountMinor,currency:intent.currency,confirmation:intent.confirmation},{status:201});
  }catch(error){
    if(error instanceof PaymentGatewayError&&error.code==="PROVIDER_UNAVAILABLE")return NextResponse.json({error:"PAYMENT_PROVIDER_UNAVAILABLE"},{status:502});
    return NextResponse.json({error:error instanceof PaymentGatewayError?"PAYMENT_REQUEST_REJECTED":"PAYMENT_INTENT_UNAVAILABLE"},{status:422});
  }
}
function sameOrigin(request:Request,appUrl:string){const origin=request.headers.get("origin");if(!origin)return false;try{return new URL(origin).origin===new URL(appUrl).origin}catch{return false}}
function isRecord(value:unknown):value is Record<string,unknown>{return typeof value==="object"&&value!==null&&!Array.isArray(value)}
