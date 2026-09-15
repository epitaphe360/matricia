"use server";

import { createHash } from "node:crypto";
import { z } from "zod";
import { isLocale } from "@/lib/i18n/locale";
import { invoiceInput, payableInput, paymentInput, reconciliationInput, statementInput } from "@/lib/provider-billing/model";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { parseMoneyToMinor } from "../devis/money";

export type BillingActionState={status:"idle"}|{status:"success";outcome:string}|{status:"error";reason:"VALIDATION"|"UNAUTHENTICATED"|"FORBIDDEN"|"CONFLICT"|"FAILED"};
const output=z.object({outcome:z.string().min(3)}).passthrough(),payableForm=payableInput.omit({proofHash:true}),paymentForm=paymentInput.omit({proofHash:true});
const t=(form:FormData,key:string)=>String(form.get(key)??"");
function err(error:{code?:string;message?:string}|null):BillingActionState{if(error?.code==="42501")return{status:"error",reason:"FORBIDDEN"};if(error?.code==="23514"||error?.code==="23505"||error?.message?.includes("IDEMPOTENCY")||error?.message?.includes("OVERALLOCATED"))return{status:"error",reason:"CONFLICT"};return{status:"error",reason:"FAILED"}}
function response(data:unknown):BillingActionState{const parsed=output.safeParse(data);return parsed.success?{status:"success",outcome:parsed.data.outcome}:{status:"error",reason:"FAILED"}}
async function authenticated(){const client=await getSupabaseServerClient(),{data}=await client.auth.getUser();return{client,user:data.user}}
async function call(name:string,args:Record<string,unknown>):Promise<BillingActionState>{const{client,user}=await authenticated();if(!user)return{status:"error",reason:"UNAUTHENTICATED"};const result=await client.rpc(name,args);return result.error?err(result.error):response(result.data)}
function locale(form:FormData){return isLocale(t(form,"locale"))}

async function fileDigest(value:FormDataEntryValue|null):Promise<string|null>{
  if(!(value instanceof File)||value.size<1||value.size>10*1024*1024||!["application/pdf","image/jpeg","image/png"].includes(value.type))return null;
  let bytes:Buffer;try{bytes=Buffer.from(await value.arrayBuffer())}catch{return null}
  const signatures:Record<string,number[]>={"application/pdf":[0x25,0x50,0x44,0x46,0x2d],"image/jpeg":[0xff,0xd8,0xff],"image/png":[0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]};
  return signatures[value.type]?.every((byte,index)=>bytes[index]===byte)?createHash("sha256").update(bytes).digest("hex"):null;
}

export async function recordPayable(_:BillingActionState,form:FormData):Promise<BillingActionState>{
  if(!locale(form))return{status:"error",reason:"VALIDATION"};const amount=parseMoneyToMinor(t(form,"grossAmount"),t(form,"currency").toUpperCase());
  const parsed=payableForm.safeParse({missionId:t(form,"missionId"),eventType:t(form,"eventType"),occurredOn:t(form,"occurredOn"),currency:t(form,"currency").toUpperCase(),grossAmountMinor:amount,clientReceiptReference:t(form,"clientReceiptReference"),idempotencyKey:t(form,"idempotencyKey")});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};const{client,user}=await authenticated();if(!user)return{status:"error",reason:"UNAUTHENTICATED"};const proofHash=await fileDigest(form.get("proofFile"));if(!proofHash)return{status:"error",reason:"VALIDATION"};const value=parsed.data;
  const result=await client.rpc("record_provider_payable_event",{p_mission_id:value.missionId,p_event_type:value.eventType,p_occurred_on:value.occurredOn,p_currency:value.currency,p_gross_amount_minor:value.grossAmountMinor,p_client_receipt_reference:value.clientReceiptReference,p_proof_hash:proofHash,p_idempotency_key:value.idempotencyKey});return result.error?err(result.error):response(result.data);
}
export async function issueStatement(_:BillingActionState,form:FormData):Promise<BillingActionState>{if(!locale(form))return{status:"error",reason:"VALIDATION"};const parsed=statementInput.safeParse({organizationId:t(form,"organizationId"),statementNumber:t(form,"statementNumber"),periodStart:t(form,"periodStart"),periodEnd:t(form,"periodEnd"),currency:t(form,"currency").toUpperCase(),idempotencyKey:t(form,"idempotencyKey")});if(!parsed.success)return{status:"error",reason:"VALIDATION"};const value=parsed.data;return call("issue_provider_statement",{p_provider_organization_id:value.organizationId,p_statement_number:value.statementNumber,p_period_start:value.periodStart,p_period_end:value.periodEnd,p_currency:value.currency,p_idempotency_key:value.idempotencyKey})}
export async function issueInvoice(_:BillingActionState,form:FormData):Promise<BillingActionState>{if(!locale(form))return{status:"error",reason:"VALIDATION"};const parsed=invoiceInput.safeParse({statementId:t(form,"statementId"),invoiceNumber:t(form,"invoiceNumber"),issuedOn:t(form,"issuedOn"),dueOn:t(form,"dueOn"),receivableAccountId:t(form,"receivableAccountId"),revenueAccountId:t(form,"revenueAccountId"),taxLiabilityAccountId:t(form,"taxLiabilityAccountId"),idempotencyKey:t(form,"idempotencyKey")});if(!parsed.success)return{status:"error",reason:"VALIDATION"};const value=parsed.data;return call("issue_provider_invoice",{p_statement_id:value.statementId,p_invoice_number:value.invoiceNumber,p_issued_on:value.issuedOn,p_due_on:value.dueOn,p_receivable_account_id:value.receivableAccountId,p_revenue_account_id:value.revenueAccountId,p_tax_liability_account_id:value.taxLiabilityAccountId,p_idempotency_key:value.idempotencyKey})}
export async function recordPayment(_:BillingActionState,form:FormData):Promise<BillingActionState>{
  if(!locale(form))return{status:"error",reason:"VALIDATION"};const amount=parseMoneyToMinor(t(form,"amount"),t(form,"currency").toUpperCase());
  const parsed=paymentForm.safeParse({organizationId:t(form,"organizationId"),paymentReference:t(form,"paymentReference"),paidOn:t(form,"paidOn"),paymentMethod:t(form,"paymentMethod"),currency:t(form,"currency").toUpperCase(),amountMinor:amount,cashAccountId:t(form,"cashAccountId"),receivableAccountId:t(form,"receivableAccountId"),idempotencyKey:t(form,"idempotencyKey")});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};const{client,user}=await authenticated();if(!user)return{status:"error",reason:"UNAUTHENTICATED"};const proofHash=await fileDigest(form.get("proofFile"));if(!proofHash)return{status:"error",reason:"VALIDATION"};const value=parsed.data;
  const result=await client.rpc("record_provider_payment",{p_provider_organization_id:value.organizationId,p_payment_reference:value.paymentReference,p_paid_on:value.paidOn,p_payment_method:value.paymentMethod,p_currency:value.currency,p_amount_minor:value.amountMinor,p_proof_hash:proofHash,p_cash_account_id:value.cashAccountId,p_receivable_account_id:value.receivableAccountId,p_idempotency_key:value.idempotencyKey});return result.error?err(result.error):response(result.data);
}
export async function reconcilePayment(_:BillingActionState,form:FormData):Promise<BillingActionState>{
  if(!locale(form))return{status:"error",reason:"VALIDATION"};const{client,user}=await authenticated();if(!user)return{status:"error",reason:"UNAUTHENTICATED"};const paymentId=t(form,"paymentId"),currencyResult=await client.from("provider_payments").select("currency").eq("id",paymentId).maybeSingle();if(currencyResult.error)return{status:"error",reason:"FAILED"};const currency=z.object({currency:z.string().regex(/^[A-Z]{3}$/u)}).safeParse(currencyResult.data);if(!currency.success)return{status:"error",reason:"FORBIDDEN"};const amount=parseMoneyToMinor(t(form,"amount"),currency.data.currency);
  const parsed=reconciliationInput.safeParse({paymentId,invoiceId:t(form,"invoiceId"),amountMinor:amount,idempotencyKey:t(form,"idempotencyKey")});if(!parsed.success)return{status:"error",reason:"VALIDATION"};const value=parsed.data,result=await client.rpc("reconcile_provider_payment",{p_payment_id:value.paymentId,p_allocations:[{invoice_id:value.invoiceId,amount_minor:value.amountMinor}],p_idempotency_key:value.idempotencyKey});return result.error?err(result.error):response(result.data);
}
