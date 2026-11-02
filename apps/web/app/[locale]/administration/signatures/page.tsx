import {randomUUID} from "node:crypto";
import {notFound,redirect} from "next/navigation";
import {AdminModulePage} from "@/modules/admin/ui/admin-module-page";
import {SignaturePolicyForms} from "@/modules/admin/screens/signatures/forms";
import {governanceSchema,policyRoles} from "@/modules/admin/screens/signatures/model";
import {hasPlatformRole,loadMyPlatformAccess,mfaRequiredMessage} from "@/modules/shared/lib/account-security/platform-access";
import {connexionHref} from "@/modules/shared/lib/auth/connexion-href";
import {isLocale} from "@/modules/shared/lib/i18n/locale";
export default async function SignaturePoliciesPage({params}:{params:Promise<{locale:string}>}){
 const{locale}=await params;if(!isLocale(locale))notFound();const access=await loadMyPlatformAccess();const ar=locale==="ar";
 if(access.status==="error"&&access.reason==="UNAUTHENTICATED")redirect(connexionHref(locale,{next:`/${locale}/administration/signatures`}));
 if(access.status!=="ok"||!hasPlatformRole(access.roles,[...policyRoles,"READ_ONLY_AUDITOR"]))return <p role="alert">{ar?"الوصول غير مسموح.":"Accès refusé."}</p>;
 if(!access.requirementSatisfied)return <p role="alert">{mfaRequiredMessage(locale)}</p>;
 const result=await access.client.rpc("list_signature_policy_governance_v1");const parsed=governanceSchema.safeParse(result.data);
 return <AdminModulePage locale={locale} active="settings" path="signatures" hubGroup="ops" title={ar?"سياسات التوقيع":"Signatures et politiques"} lead={ar?"سياسات محددة الإصدار والبيئة بمراجعة مستقلة.":"Politiques versionnées, liées à l’environnement et soumises à une revue indépendante."}>
 <div className="space-y-6"><p role="note">{ar?"لم يُعتمد بعد مزوّد حقيقي أو مستوى قانوني. المحاكاة غير تعاقدية ومؤقتة في التطوير أو الاختبار فقط. إدخال مرجع لا يثبت تثبيت موصل حقيقي ولا موافقة قانونية.":"Le fournisseur et le niveau juridique réels restent à valider. La simulation est temporaire et non contractuelle, en développement ou staging uniquement. Saisir une référence ne prouve ni un adaptateur installé ni une approbation juridique réelle."}</p>
 {result.error||!parsed.success?<p role="alert">{ar?"تعذّر تحميل السياسات.":"Les politiques sont indisponibles."}</p>:<><p>{ar?"بيئة قاعدة البيانات":"Environnement de la base"} : {parsed.data.environment??(ar?"غير مهيأة":"non configuré")}</p>{!parsed.data.can_write?<p>{ar?"قراءة فقط.":"Lecture seule."}</p>:null}<SignaturePolicyForms locale={locale} data={parsed.data} proposalKey={randomUUID()} simulationKey={randomUUID()} cancellationKeys={Object.fromEntries(parsed.data.local_envelopes.map(envelope=>[envelope.id,randomUUID()]))}/></>}
 </div></AdminModulePage>;
}
