"use server";
import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { parseMoneyInput } from "@/modules/shared/lib/money-input";
import { readAllPages } from "@/modules/shared/lib/data/read-pages";
export type ProviderAmendmentState={status:"idle"}|{status:"success";amendmentId:string}|{status:"error";reason:"VALIDATION"|"UNAUTHENTICATED"|"FORBIDDEN"|"MFA"|"UNAVAILABLE"|"CONFLICT"};
const schema=z.object({locale:z.enum(["fr","ar"]),contractId:z.string().uuid(),versionId:z.string().uuid(),contentHash:z.string().regex(/^[0-9a-f]{64}$/u),reason:z.string().trim().min(3).max(2000),scopeDelta:z.string().trim().min(2).max(4000),priceDelta:z.string().max(100),deadlineDeltaDays:z.coerce.number().int().min(-3650).max(3650),idempotencyKey:z.string().uuid()});
export async function proposeProviderAmendment(_:ProviderAmendmentState,form:FormData):Promise<ProviderAmendmentState>{
 const input=schema.safeParse(Object.fromEntries(form));if(!input.success)return{status:"error",reason:"VALIDATION"};const p=input.data;
 const ids=z.array(z.string().uuid()).max(50).safeParse(form.getAll("lineId")),labels=z.array(z.string().trim().min(1).max(500)).max(50).safeParse(form.getAll("lineLabel"));if(!ids.success||!labels.success||ids.data.length!==labels.data.length||new Set(ids.data).size!==ids.data.length)return{status:"error",reason:"VALIDATION"};
 const c=await getSupabaseServerClient(),auth=await c.auth.getUser();if(!auth.data.user)return{status:"error",reason:"UNAUTHENTICATED"};const aal=await c.auth.mfa.getAuthenticatorAssuranceLevel();if(aal.error||aal.data?.currentLevel!=="aal2")return{status:"error",reason:"MFA"};
 const result=await c.from("contract_versions").select("id,contract_id,currency,content_hash").eq("id",p.versionId).eq("contract_id",p.contractId).maybeSingle(),version=z.object({id:z.string().uuid(),contract_id:z.string().uuid(),currency:z.string().regex(/^[A-Z]{3}$/u),content_hash:z.string()}).safeParse(result.data);
 if(result.error)return{status:"error",reason:"UNAVAILABLE"};if(!version.success)return{status:"error",reason:"FORBIDDEN"};if(version.data.content_hash!==p.contentHash)return{status:"error",reason:"CONFLICT"};
 const amount=parseMoneyInput(p.priceDelta,version.data.currency);if(amount===null||BigInt(amount)<BigInt("-9223372036854775808")||BigInt(amount)>BigInt("9223372036854775807"))return{status:"error",reason:"VALIDATION"};
 const itemsResult=await readAllPages((from,to)=>c.from("contract_items").select("sort_order").eq("contract_version_id",p.versionId).order("sort_order").order("id").range(from,to)),items=z.array(z.object({sort_order:z.number().int().positive()})).safeParse(itemsResult.data);
 if(itemsResult.error||!items.success)return{status:"error",reason:"UNAVAILABLE"};const maxOrder=items.data.reduce((max,item)=>Math.max(max,item.sort_order),0);
 const delta=ids.data.map((id,index)=>({operation:"ADD",item_type:"DELIVERABLE",item_key:`ADDED_${id.replaceAll("-","").toUpperCase()}`,label_fr:labels.data[index],label_ar:labels.data[index],details:{},sort_order:maxOrder+index+1}));
 const command=await c.rpc("propose_provider_contract_amendment_v1",{p_contract_id:p.contractId,p_expected_contract_version_id:p.versionId,p_expected_contract_hash:p.contentHash,p_reason:p.reason,p_scope_delta:{description:p.scopeDelta},p_price_delta_minor:amount,p_deadline_delta_days:p.deadlineDeltaDays,p_deliverables_delta:delta,p_idempotency_key:p.idempotencyKey});
 if(command.error)return{status:"error",reason:command.error.code==="42501"?"FORBIDDEN":["40001","55000","23505"].includes(command.error.code??"")?"CONFLICT":"UNAVAILABLE"};const response=z.object({outcome:z.literal("CONTRACT_AMENDMENT_DRAFTED"),amendment_id:z.string().uuid()}).safeParse(command.data);return response.success?{status:"success",amendmentId:response.data.amendment_id}:{status:"error",reason:"UNAVAILABLE"};
}
