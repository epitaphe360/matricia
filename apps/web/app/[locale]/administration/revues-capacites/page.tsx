import Link from "next/link";
import { notFound } from "next/navigation";
import { z } from "zod";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { AdminModulePage } from "@/modules/admin/ui/admin-module-page";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { CapabilityResolutionForm } from "@/modules/admin/screens/capability-reviews/resolution-form";
export default async function CapabilityReviewsPage({params}:{params:Promise<{locale:string}>}){
 const{locale}=await params;if(!isLocale(locale))notFound();const ar=locale==="ar";
 const r=await(await getSupabaseServerClient()).rpc("get_admin_capability_reviews_v1");
 const parsed=z.array(z.object({id:z.string().uuid(),userId:z.string().uuid(),organizationId:z.string().uuid(),organizationName:z.string(),requestedCapabilities:z.array(z.string()),status:z.string(),resolution:z.string().nullable(),roles:z.array(z.string())})).safeParse(r.data);
 return <AdminModulePage locale={locale} active="settings" path="revues-capacites" title={ar?"مراجعات القدرات":"Revues de capacités"} lead={ar?"المستلم: مسؤول ماتريسيا / مسؤول الامتثال. الصلاحيات الفعلية تتبع الأدوار المعتمدة وسياسات قاعدة البيانات.":"Destinataires : Matricia Admin / Conformité. Les droits effectifs suivent les rôles autorisés et les politiques de la base."}>{r.error||!parsed.success?<p role="alert">{ar?"الوصول مرفوض أو البيانات غير متاحة.":"Accès refusé ou données indisponibles."}</p>:<div className="client-stack">{!parsed.data.length?<p>{ar?"لا طلبات متاحة.":"Aucune demande visible."}</p>:parsed.data.map((review)=><article key={review.id} className="client-card"><h2>{review.organizationName}</h2><p>{review.status==="PENDING_POLICY_REVIEW"?(ar?"قيد الانتظار":"EN ATTENTE"):review.resolution}</p><p>{review.requestedCapabilities.join(", ")}</p><p>{ar?"لا يتم منح صلاحيات إضافية بهذه المراجعة. اختاروا دوراً معتمداً ثم تحققوا من تطبيقه أو ارفضوا الطلب.":"Cette revue n’accorde aucun privilège supplémentaire. Choisissez un rôle autorisé, vérifiez son application, ou refusez la demande."}</p><Link href={`/${locale}/administration/utilisateurs/${review.userId}/roles?organizationId=${review.organizationId}`}>{ar?"طلب تعديل الدور بأربع أعين":"Demander un changement de rôle à quatre yeux"}</Link>{review.status==="PENDING_POLICY_REVIEW"?<CapabilityResolutionForm locale={locale} reviewId={review.id} roles={review.roles}/>:null}</article>)}</div>}</AdminModulePage>;
}
