import { notFound } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { NeedFlow } from "@/components/public-journey/need-flow";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { savePublicNeedIntake } from "./actions";
export default async function NeedPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ q?: string | string[]; service?: string | string[] }> }) {
  const { locale } = await params; const query = await searchParams; if (!isLocale(locale)) notFound();
  const text = typeof query.q === "string" ? query.q.slice(0, 500) : typeof query.service === "string" ? query.service.slice(0, 120) : "";
  const client=await getSupabaseServerClient(),auth=await client.auth.getUser();
  let organizations:{id:string;name:string}[]=[];
  if(auth.data.user){
    const memberships=await client.from("organization_memberships").select("id,organization_id").eq("user_id",auth.data.user.id).eq("status","ACTIVE").limit(100);
    const ids=(memberships.data??[]).map(item=>item.id),roles=ids.length?await client.from("organization_member_roles").select("membership_id").in("membership_id",ids).in("role_code",["CLIENT_OWNER","CLIENT_ADMIN","CLIENT_BUYER"]).is("revoked_at",null).limit(300):{data:[]};
    const writable=new Set((roles.data??[]).map(item=>item.membership_id)),organizationIds=[...new Set((memberships.data??[]).filter(item=>writable.has(item.id)).map(item=>item.organization_id))];
    const result=organizationIds.length?await client.from("organizations").select("id,display_name").in("id",organizationIds).order("display_name"):{data:[]};
    organizations=(result.data??[]).map(item=>({id:item.id,name:item.display_name}));
  }
  return <NeedFlow locale={locale} initialNeed={text} authenticated={Boolean(auth.data.user)} organizations={organizations} saveAction={savePublicNeedIntake}/>;
}
