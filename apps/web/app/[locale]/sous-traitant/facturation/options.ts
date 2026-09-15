import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const row=z.object({id:z.string().uuid(),status:z.string(),started_at:z.string().nullable()});
export type MissionOption={id:string;label:string};
export async function loadBillingMissionOptions(organizationId:string,locale:"fr"|"ar"):Promise<MissionOption[]>{
  if(!z.string().uuid().safeParse(organizationId).success)return[];
  const client=await getSupabaseServerClient(),result=await client.from("missions").select("id,status,started_at").eq("provider_organization_id",organizationId).in("status",["READY","ACTIVE","IN_PROGRESS","DELIVERY_PENDING","CLIENT_REVIEW"]).order("updated_at",{ascending:false}).limit(100);
  const parsed=z.array(row).max(100).safeParse(result.data);if(result.error||!parsed.success)return[];
  return parsed.data.map((mission,index)=>({id:mission.id,label:locale==="fr"?`Mission ${index+1} · ${mission.status.replaceAll("_"," ")}${mission.started_at?` · démarrée le ${new Intl.DateTimeFormat("fr-MA").format(new Date(mission.started_at))}`:""}`:`المهمة ${index+1} · ${mission.status.replaceAll("_"," ")}${mission.started_at?` · بدأت في ${new Intl.DateTimeFormat("ar-MA").format(new Date(mission.started_at))}`:""}`}));
}
