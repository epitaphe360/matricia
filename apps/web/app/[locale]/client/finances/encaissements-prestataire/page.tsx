import Link from"next/link";
import{notFound,redirect}from"next/navigation";
import{isLocale}from"@/modules/shared/lib/i18n/locale";
import{getSupabaseServerClient}from"@/modules/shared/lib/supabase/server";
import{loadBillingWorkspace}from"@/modules/provider/data/billing/workspace";
import{ProviderBillingWorkspace}from"@/modules/provider/screens/facturation/workspace-panel";
export default async function ProviderReceiptConfirmationPage({params,searchParams}:{params:Promise<{locale:string}>;searchParams:Promise<{organizationId?:string}>}){
 const[{locale},q]=await Promise.all([params,searchParams]);if(!isLocale(locale))notFound();const c=await getSupabaseServerClient(),{data:a}=await c.auth.getUser();if(!a.user)redirect(`/${locale}/connexion`);const v=await loadBillingWorkspace();if(!v)return<p role="alert">{locale==="ar"?"تعذرت قراءة التحصيلات.":"Impossible de charger les encaissements."}</p>;const filtered={...v,declarations:v.declarations.filter(d=>d.kind==="PAYABLE"&&(!q.organizationId||d.client_organization_id===q.organizationId))};return<main dir={locale==="ar"?"rtl":"ltr"} className="mx-auto max-w-5xl space-y-4 p-4"><Link href={`/${locale}/client/finances${q.organizationId?`?organizationId=${encodeURIComponent(q.organizationId)}`:""}`}>{locale==="ar"?"المركز المالي":"Centre financier"}</Link><h1>{locale==="ar"?"تأكيد التحصيلات المصرح بها من مقدمي الخدمات":"Confirmer les encaissements déclarés par vos prestataires"}</h1><ProviderBillingWorkspace value={filtered} locale={locale} client/></main>;
}
