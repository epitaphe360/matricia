"use server";
import { createHash } from "node:crypto";
import { z } from "zod";
import { isLocale } from "@/lib/i18n/locale";
import { deliverySubmissionSchema } from "@/lib/provider-missions/model";
import { getSupabaseServerClient } from "@/lib/supabase/server";
export type DeliveryActionState={status:"idle"}|{status:"success";outcome:string}|{status:"error";reason:"VALIDATION"|"UNAUTHENTICATED"|"FORBIDDEN"|"CONFLICT"|"FAILED"};
const output=z.object({outcome:z.string().min(3)}).passthrough();const text=(form:FormData,key:string)=>String(form.get(key)??"");
export async function submitProviderDelivery(_:DeliveryActionState,form:FormData):Promise<DeliveryActionState>{
  if(!isLocale(text(form,"locale")))return{status:"error",reason:"VALIDATION"};
  const parsed=deliverySubmissionSchema.safeParse({deliverableId:text(form,"deliverableId"),description:text(form,"description"),linksText:text(form,"linksText"),proofType:text(form,"proofType"),proofLocation:text(form,"proofLocation"),proofNote:text(form,"proofNote"),idempotencyKey:text(form,"idempotencyKey")});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};const value=parsed.data;
  const isUrl=value.proofLocation.startsWith("https://");const proofBase={type:value.proofType,storage_path:isUrl?null:value.proofLocation,url:isUrl?value.proofLocation:null,metadata:{note:value.proofNote}};
  const evidenceHash=createHash("sha256").update(JSON.stringify(proofBase)).digest("hex");
  const client=await getSupabaseServerClient();const{data:auth}=await client.auth.getUser();if(!auth.user)return{status:"error",reason:"UNAUTHENTICATED"};
  const result=await client.rpc("submit_delivery",{p_deliverable_id:value.deliverableId,p_description:value.description,p_links:value.links,p_proofs:[{...proofBase,evidence_hash:evidenceHash}],p_idempotency_key:value.idempotencyKey});
  if(result.error){if(result.error.code==="42501")return{status:"error",reason:"FORBIDDEN"};if(result.error.code==="23505"||result.error.code==="55000"||result.error.message?.includes("IDEMPOTENCY"))return{status:"error",reason:"CONFLICT"};return{status:"error",reason:"FAILED"};}
  const response=output.safeParse(result.data);return response.success?{status:"success",outcome:response.data.outcome}:{status:"error",reason:"FAILED"};
}
