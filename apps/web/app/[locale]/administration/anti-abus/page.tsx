import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { AntiAbusePanel } from "@/modules/admin/screens/anti-abus/anti-abuse-panel";
import { AdminModulePage } from "@/modules/admin/ui/admin-module-page";

const MUTATION_ROLES = new Set(["SUPER_ADMIN", "MATRICIA_ADMIN"]);

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const client = await getSupabaseServerClient();
  const { data: auth, error: authError } = await client.auth.getUser();
  if (authError || !auth.user) redirect(`/${locale}/connexion`);

  const [rules, cases, roles] = await Promise.all([
    client.from("abuse_rule_versions").select("id,rule_code,version,event_type,window_seconds,max_events,review_score,block_score,status").order("created_at", { ascending: false }).limit(100),
    client.from("abuse_review_cases").select("id,subject_type,subject_hash,risk_score,event_count,recommended_action,status,row_version,opened_at").eq("status", "OPEN").order("risk_score", { ascending: false }).limit(100),
    client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).limit(20),
  ]);

  const failed = rules.error ?? cases.error ?? roles.error;
  const roleCodes = new Set((roles.data ?? []).map((row) => String(row.role_code)));
  const canMutate = [...roleCodes].some((role) => MUTATION_ROLES.has(role));
  const ar = locale === "ar";

  return (
    <AdminModulePage
      locale={locale}
      active="pilot"
      path="anti-abus"
      title={ar ? "مراقبة إساءة الاستخدام" : "Contrôle des abus"}
      lead={ar ? "قواعد وإشارات مراجعة دون نجاح زائف." : "Règles et signaux de revue — sans succès artificiel."}
    >
      {failed ? (
        <Alert variant="destructive">
          <AlertTitle>{ar ? (failed.code === "42501" ? "الوصول مرفوض" : "تعذر التحميل") : (failed.code === "42501" ? "Accès refusé" : "Chargement impossible")}</AlertTitle>
          <AlertDescription>{ar ? "لم يتم عرض أي نجاح أو قائمة فارغة مصطنعة. تحقق من صلاحياتك أو أعد المحاولة." : "Aucun succès ni liste vide artificielle n’est affiché. Vérifiez vos droits ou réessayez."}</AlertDescription>
        </Alert>
      ) : (
        <div className="admin-panel space-y-6">
          <AntiAbusePanel locale={locale} rules={(rules.data ?? []) as never} cases={(cases.data ?? []) as never} canMutate={canMutate} />
          <section id="rls" className="scroll-mt-24 rounded-xl border bg-card p-5">
            <h2 className="text-xl font-semibold">{ar ? "الصفوف والتحكم في الوصول" : "RLS et contrôle des accès"}</h2>
            <p className="mt-2 leading-7 text-muted-foreground">
              {ar
                ? "الإدارة لا تتجاوز سياسات الصفوف. القواعد والحالات أعلاه تُقرأ بالدور الحالي فقط."
                : "L’administration ne contourne pas les politiques RLS. Les règles et cas ci-dessus sont lus avec le rôle courant uniquement."}
            </p>
          </section>
        </div>
      )}
    </AdminModulePage>
  );
}
