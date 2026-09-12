import { randomUUID } from "node:crypto";
import { DemoPaymentGateway, PaymentGatewayError } from "@matricia/infrastructure";
import { NextResponse } from "next/server";
import { getDemoPaymentWebhookSecret } from "@/lib/env";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

const maximumBodyBytes=1_048_576;
export async function POST(request:Request){
  const declared=Number(request.headers.get("content-length")??"0");
  if(!Number.isSafeInteger(declared)||declared>maximumBodyBytes)return NextResponse.json({error:"PAYLOAD_TOO_LARGE"},{status:413});
  const signature=request.headers.get("x-matricia-signature");if(!signature)return NextResponse.json({error:"INVALID_SIGNATURE"},{status:401});
  const rawBody=new Uint8Array(await request.arrayBuffer());if(rawBody.byteLength===0||rawBody.byteLength>maximumBodyBytes)return NextResponse.json({error:"INVALID_PAYLOAD"},{status:400});
  let event;
  try{event=await new DemoPaymentGateway().verifyWebhook(rawBody,signature,getDemoPaymentWebhookSecret());}catch(error){return NextResponse.json({error:error instanceof PaymentGatewayError&&error.code==="INVALID_SIGNATURE"?"INVALID_SIGNATURE":"INVALID_EVENT"},{status:error instanceof PaymentGatewayError&&error.code==="INVALID_SIGNATURE"?401:400});}
  const{data,error}=await getSupabaseAdminClient().rpc("process_verified_subscription_payment",{p_gateway:event.gateway,p_provider_event_id:event.providerEventId,p_provider_intent_id:event.providerIntentId,p_event_type:event.eventType,p_amount_minor:event.amountMinor,p_currency:event.currency,p_paid_at:event.paidAt,p_payment_reference:event.paymentReference,p_payload_hash:event.payloadHash,p_signature_fingerprint:event.signatureFingerprint,p_correlation_id:randomUUID()});
  if(error)return NextResponse.json({error:"PAYMENT_EVENT_REJECTED"},{status:409});
  return NextResponse.json({received:true,replayed:isRecord(data)&&data.replayed===true});
}
function isRecord(value:unknown):value is Record<string,unknown>{return typeof value==="object"&&value!==null&&!Array.isArray(value)}
