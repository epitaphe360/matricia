import{z}from"zod";
import{getSupabaseServerClient}from"@/modules/shared/lib/supabase/server";
import{categoryRows,centerPayload,templateRows,type NotificationDashboard}from"./model";

const member=z.object({organization_id:z.string().uuid(),organizations:z.object({display_name:z.string().min(1)})});

export async function loadNotificationCenter(locale:"fr"|"ar"):Promise<{status:"success";dashboard:NotificationDashboard}|{status:"error";reason:"UNAUTHENTICATED"|"NO_ORGANIZATION"|"QUERY_FAILED"|"INVALID_RESPONSE"}>{
 const c=await getSupabaseServerClient();const{data:a}=await c.auth.getUser();if(!a.user)return{status:"error",reason:"UNAUTHENTICATED"};
 const mr=await c.from("organization_memberships").select("organization_id,organizations!inner(display_name)").eq("user_id",a.user.id).eq("status","ACTIVE").limit(1).maybeSingle();if(mr.error)return{status:"error",reason:"QUERY_FAILED"};
 const m=member.safeParse(mr.data);if(!m.success)return{status:"error",reason:mr.data?"INVALID_RESPONSE":"NO_ORGANIZATION"};
 const[center,categories,templates]=await Promise.all([
  c.rpc("list_notification_center",{p_organization_id:m.data.organization_id,p_limit:100}),
  c.from("notification_preference_categories").select("code,label_fr,label_ar,mandatory").eq("status","ACTIVE").order("code"),
  c.from("notification_template_versions").select("id,template_code,version,event_type,category_code,locale,subject_template,body_template,cta_path_template,priority,mandatory,channels,variable_keys,effective_from,content_hash").eq("status","ACTIVE").order("template_code").order("version",{ascending:false}).order("locale"),
 ]);
 if(center.error||categories.error||templates.error)return{status:"error",reason:"QUERY_FAILED"};
 const cp=centerPayload.safeParse(center.data),cr=categoryRows.safeParse(categories.data),tr=templateRows.safeParse(templates.data);if(!cp.success||!cr.success||!tr.success)return{status:"error",reason:"INVALID_RESPONSE"};
 const canViewDeliveryOperations=false;
 return{status:"success",dashboard:{organizationId:m.data.organization_id,organizationName:m.data.organizations.display_name,canViewDeliveryOperations,categories:cr.data.map(x=>({code:x.code,label:locale==="ar"?x.label_ar:x.label_fr,mandatory:x.mandatory})),preferences:cp.data.preferences,notifications:cp.data.notifications.map(n=>canViewDeliveryOperations?n:{...n,deliveries:[]}),templates:tr.data}};
}
