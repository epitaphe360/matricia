"use server";

import { createHash, randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const payloadSchema=z.object({need:z.string().trim().min(10).max(1200),location:z.string().max(1200),timing:z.string().max(1200),constraints:z.string().max(1200)}).strict();
const inputSchema=z.object({locale:z.enum(["fr","ar"]),organizationId:z.string().uuid(),payload:z.string().max(6000)});
export type SaveNeedState={status:"idle"}|{status:"success";intakeId:string}|{status:"error";reason:"VALIDATION"|"FORBIDDEN"|"UNAVAILABLE"};

export async function savePublicNeedIntake(_:SaveNeedState,data:FormData):Promise<SaveNeedState>{
  const input=inputSchema.safeParse({locale:data.get("locale"),organizationId:data.get("organizationId"),payload:data.get("payload")});
  if(!input.success)return{status:"error",reason:"VALIDATION"};
  let raw:unknown;try{raw=JSON.parse(input.data.payload)}catch{return{status:"error",reason:"VALIDATION"}}
  const payload=payloadSchema.safeParse(raw);if(!payload.success)return{status:"error",reason:"VALIDATION"};
  const idempotencyKey=createHash("sha256").update(`${input.data.organizationId}:${JSON.stringify(payload.data)}`).digest("hex");
  const client=await getSupabaseServerClient();
  const result=await client.rpc("save_public_need_intake",{p_organization_id:input.data.organizationId,p_payload:payload.data,p_locale:input.data.locale,p_idempotency_key:idempotencyKey,p_correlation_id:randomUUID()});
  if(result.error)return{status:"error",reason:result.error.code==="42501"?"FORBIDDEN":"UNAVAILABLE"};
  const response=z.object({outcome:z.literal("PUBLIC_NEED_INTAKE_SAVED"),intake_id:z.string().uuid(),status:z.literal("DRAFT_REVIEW")}).passthrough().safeParse(result.data);
  if(!response.success)return{status:"error",reason:"UNAVAILABLE"};
  revalidatePath(`/${input.data.locale}/client/demandes`);
  return{status:"success",intakeId:response.data.intake_id};
}
