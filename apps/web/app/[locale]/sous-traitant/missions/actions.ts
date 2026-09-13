"use server";
import { createHash } from "node:crypto";
import { z } from "zod";
import { isLocale } from "@/lib/i18n/locale";
import { checklistCompletionSchema,deliverySubmissionSchema, milestoneSubmissionSchema } from "@/lib/provider-missions/model";
import { getSupabaseServerClient } from "@/lib/supabase/server";
export type DeliveryActionState={status:"idle"}|{status:"success";outcome:string}|{status:"error";reason:"VALIDATION"|"UNAUTHENTICATED"|"FORBIDDEN"|"CONFLICT"|"FAILED"};
const output=z.object({outcome:z.string().min(3)}).passthrough();const text=(form:FormData,key:string)=>String(form.get(key)??"");
export async function submitProviderDelivery(_:DeliveryActionState,form:FormData):Promise<DeliveryActionState>{
  if(!isLocale(text(form,"locale")))return{status:"error",reason:"VALIDATION"};
  const client=await getSupabaseServerClient();const{data:auth}=await client.auth.getUser();if(!auth.user)return{status:"error",reason:"UNAUTHENTICATED"};
  const file=form.get("proofFile");
  if(!(file instanceof File)||file.size<1||file.size>10*1024*1024||!["application/pdf","image/jpeg","image/png"].includes(file.type))return{status:"error",reason:"VALIDATION"};
  let bytes:Buffer;try{bytes=Buffer.from(await file.arrayBuffer())}catch{return{status:"error",reason:"VALIDATION"};}
  const signatures:Record<string,number[]>={"application/pdf":[0x25,0x50,0x44,0x46,0x2d],"image/jpeg":[0xff,0xd8,0xff],"image/png":[0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]};const signature=signatures[file.type];if(!signature||!signature.every((byte,index)=>bytes[index]===byte))return{status:"error",reason:"VALIDATION"};
  const deliverableId=text(form,"deliverableId"),idempotencyKey=text(form,"idempotencyKey"),digest=createHash("sha256").update(bytes).digest("hex"),safeName=file.name.normalize("NFKD").replace(/[^a-zA-Z0-9._-]+/g,"-").replace(/^-+|-+$/g,"").slice(0,120)||"proof";const objectPath=`${auth.user.id}/${deliverableId}/${idempotencyKey}/${safeName}`;
  const parsed=deliverySubmissionSchema.safeParse({deliverableId,description:text(form,"description"),linksText:text(form,"linksText"),proofType:file.type.startsWith("image/")?"IMAGE":"DOCUMENT",proofLocation:objectPath,evidenceHash:digest,proofNote:text(form,"proofNote"),idempotencyKey});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};const value=parsed.data;
  const bucket=client.storage.from("delivery-proofs"),upload=await bucket.upload(objectPath,bytes,{contentType:file.type,upsert:false});const alreadyUploaded=upload.error&&"statusCode"in upload.error&&String(upload.error.statusCode)==="409",createdObject=!upload.error;
  if(upload.error&&!alreadyUploaded)return{status:"error",reason:"FAILED"};
  if(alreadyUploaded){const existing=await bucket.download(objectPath);if(existing.error||!existing.data)return{status:"error",reason:"CONFLICT"};let existingDigest:string;try{existingDigest=createHash("sha256").update(Buffer.from(await existing.data.arrayBuffer())).digest("hex")}catch{return{status:"error",reason:"CONFLICT"};}if(existingDigest!==digest)return{status:"error",reason:"CONFLICT"};}
  const proofBase={type:value.proofType,storage_path:value.proofLocation,url:null,metadata:{note:value.proofNote,original_file_name:file.name,mime_type:file.type,size_bytes:file.size,upload_binding_version:1}};
  const result=await client.rpc("submit_delivery",{p_deliverable_id:value.deliverableId,p_description:value.description,p_links:value.links,p_proofs:[{...proofBase,evidence_hash:value.evidenceHash}],p_idempotency_key:value.idempotencyKey});
  if(result.error){if(createdObject)await bucket.remove([objectPath]);if(result.error.code==="42501")return{status:"error",reason:"FORBIDDEN"};if(result.error.code==="23505"||result.error.code==="55000"||result.error.message?.includes("IDEMPOTENCY"))return{status:"error",reason:"CONFLICT"};return{status:"error",reason:"FAILED"};}
  const response=output.safeParse(result.data);return response.success?{status:"success",outcome:response.data.outcome}:{status:"error",reason:"FAILED"};
}

export async function submitProviderMilestone(_:DeliveryActionState,form:FormData):Promise<DeliveryActionState>{
  if(!isLocale(text(form,"locale")))return{status:"error",reason:"VALIDATION"};
  const parsed=milestoneSubmissionSchema.safeParse({milestoneId:text(form,"milestoneId"),expectedRowVersion:text(form,"expectedRowVersion"),idempotencyKey:text(form,"idempotencyKey")});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};
  const client=await getSupabaseServerClient();const{data:auth}=await client.auth.getUser();if(!auth.user)return{status:"error",reason:"UNAUTHENTICATED"};
  const result=await client.rpc("submit_mission_milestone",{p_milestone_id:parsed.data.milestoneId,p_expected_row_version:parsed.data.expectedRowVersion,p_idempotency_key:parsed.data.idempotencyKey});
  if(result.error){if(result.error.code==="42501")return{status:"error",reason:"FORBIDDEN"};if(result.error.code==="55000"||result.error.message?.includes("IDEMPOTENCY"))return{status:"error",reason:"CONFLICT"};return{status:"error",reason:"FAILED"};}
  const response=output.safeParse(result.data);return response.success?{status:"success",outcome:response.data.outcome}:{status:"error",reason:"FAILED"};
}

export async function completeProviderChecklistItem(_:DeliveryActionState,form:FormData):Promise<DeliveryActionState>{
  if(!isLocale(text(form,"locale")))return{status:"error",reason:"VALIDATION"};
  const parsed=checklistCompletionSchema.safeParse({itemId:text(form,"itemId"),expectedStatus:text(form,"expectedStatus"),proofId:text(form,"proofId"),idempotencyKey:text(form,"idempotencyKey")});
  if(!parsed.success)return{status:"error",reason:"VALIDATION"};
  const client=await getSupabaseServerClient();const{data:auth}=await client.auth.getUser();if(!auth.user)return{status:"error",reason:"UNAUTHENTICATED"};
  const result=await client.rpc("complete_mission_checklist_item",{p_item_id:parsed.data.itemId,p_expected_status:parsed.data.expectedStatus,p_proof_id:parsed.data.proofId||null,p_idempotency_key:parsed.data.idempotencyKey});
  if(result.error){if(result.error.code==="42501")return{status:"error",reason:"FORBIDDEN"};if(result.error.code==="55000"||result.error.message?.includes("IDEMPOTENCY"))return{status:"error",reason:"CONFLICT"};return{status:"error",reason:"FAILED"};}
  const response=output.safeParse(result.data);return response.success?{status:"success",outcome:response.data.outcome}:{status:"error",reason:"FAILED"};
}
