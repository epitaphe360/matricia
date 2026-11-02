import {randomUUID} from "node:crypto";
import {notFound, redirect} from "next/navigation";
import {isLocale} from "@/modules/shared/lib/i18n/locale";
import {getSupabaseServerClient} from "@/modules/shared/lib/supabase/server";
import {AdminModulePage} from "@/modules/admin/ui/admin-module-page";
import {contractPolicyConsoleSchema} from "@/modules/admin/screens/contract-policies/model";
import {ContractPolicyPanel} from "@/modules/admin/screens/contract-policies/panel";
export default async function ContractPoliciesPage({params, searchParams}: {params: Promise<{locale: string}>; searchParams: Promise<{page?: string}>}) {
  const [{locale}, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const client = await getSupabaseServerClient();
  const {data: auth} = await client.auth.getUser();
  if (!auth.user) redirect(`/${locale}/connexion`);
  const page = Number(query.page ?? "1");
  const result = await client.rpc("get_admin_contract_policy_console_v1", {p_page: Number.isSafeInteger(page) && page > 0 ? page : 1});
  const data = contractPolicyConsoleSchema.safeParse(result.data), ar = locale === "ar";
  const keys: Record<string, string> = {create: randomUUID()};
  if (data.success) for (const policy of data.data.policies) keys[policy.id] = randomUUID();
  return <AdminModulePage locale={locale} active="finance" path="politiques-contrats" title={ar ? "سياسات العقود والعمولات" : "Politiques contractuelles et commissions"} lead={ar ? "نصوص ونسب مؤرخة ومعتمدة بشكل مستقل." : "Textes et taux versionnés, datés et approuvés indépendamment."}>
    {result.error || !data.success ? <p role="alert">{ar ? "البيانات غير متاحة أو الوصول مرفوض. تحققوا من المصادقة والصلاحيات." : "Données indisponibles ou accès refusé. Vérifiez la MFA et les habilitations."}</p> : <ContractPolicyPanel locale={locale} data={data.data} actorId={auth.user.id} keys={keys}/>}
  </AdminModulePage>;
}
