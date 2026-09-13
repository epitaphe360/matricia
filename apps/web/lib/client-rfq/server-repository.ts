import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createClientRfqRepository } from "./repository";

export async function createServerClientRfqRepository(){const client=await getSupabaseServerClient();return createClientRfqRepository({
 async userId(){const{data,error}=await client.auth.getUser();return error?null:data.user?.id??null;},
 async memberships(userId){return await client.from("organization_memberships").select("id,organization_id").eq("user_id",userId).eq("status","ACTIVE").limit(100);},
 async roles(ids){if(ids.length===0)return{data:[],error:null};return await client.from("organization_member_roles").select("membership_id,role_code,revoked_at").in("membership_id",ids).in("role_code",["CLIENT_OWNER","CLIENT_ADMIN","CLIENT_BUYER","CLIENT_VIEWER"]).limit(300);},
 async organizations(ids){if(ids.length===0)return{data:[],error:null};return await client.from("organizations").select("id,display_name").in("id",ids).order("display_name").limit(100);},
 async requests(ids,requestId){if(ids.length===0)return{data:[],error:null};let q=client.from("service_requests").select("id,client_organization_id,library_id,service_id,current_version_id,status,created_at,row_version").in("client_organization_id",ids).order("created_at",{ascending:false}).limit(500);if(requestId)q=q.eq("id",requestId);return await q;},
 async versions(ids){if(ids.length===0)return{data:[],error:null};return await client.from("service_request_versions").select("id,request_id,description,urgency,desired_date,budget_minor,currency_code").in("request_id",ids).order("version_number",{ascending:false}).limit(500);},
 async matchingRuns(ids){if(ids.length===0)return{data:[],error:null};return await client.from("matching_runs").select("id,request_id,status").in("request_id",ids).order("started_at",{ascending:false}).limit(500);},
 async rfqs(ids){if(ids.length===0)return{data:[],error:null};return await client.from("rfqs").select("id,request_id,deadline,status").in("request_id",ids).order("version_number",{ascending:false}).limit(500);},
 async quotes(ids){if(ids.length===0)return{data:[],error:null};return await client.from("quotes").select("id,rfq_id,status").in("rfq_id",ids).limit(2000);},async comparisons(rfqId){return await client.from("quote_comparison_snapshots").select("id,rfq_id,normalization_version,currency,comparison,created_at").eq("rfq_id",rfqId).order("created_at",{ascending:false}).limit(1);},async rpc(name,input){return await client.rpc(name,input)}
});}
