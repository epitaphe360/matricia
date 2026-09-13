import { getSupabaseServerClient } from "@/lib/supabase/server";
import { adminV41OverviewSchema, type AdminV41Result } from "./model";

export async function loadAdminV41Overview():Promise<AdminV41Result>{
 const client=await getSupabaseServerClient();
 const{data:auth,error:authError}=await client.auth.getUser();
 if(authError||!auth.user)return{status:"error",reason:"UNAUTHENTICATED"};
 const response=await client.rpc("list_admin_v41_overview",{p_limit:50});
 if(response.error)return{status:"error",reason:response.error.code==="42501"?"FORBIDDEN":"UNAVAILABLE"};
 const parsed=adminV41OverviewSchema.safeParse(response.data);
 return parsed.success?{status:"success",value:parsed.data}:{status:"error",reason:"INVALID_RESPONSE"};
}
