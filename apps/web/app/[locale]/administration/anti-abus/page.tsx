import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { AntiAbusePanel } from "./anti-abuse-panel";

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
  if (failed) {
    const forbidden = failed.code === "42501";
    return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-7xl"><Alert variant="destructive"><AlertTitle>{locale === "ar" ? (forbidden ? "الوصول مرفوض" : "تعذر التحميل") : (forbidden ? "Accès refusé" : "Chargement impossible")}</AlertTitle><AlertDescription>{locale === "ar" ? "لم يتم عرض أي نجاح أو قائمة فارغة مصطنعة. تحقق من صلاحياتك أو أعد المحاولة." : "Aucun succès ni liste vide artificielle n’est affiché. Vérifiez vos droits ou réessayez."}</AlertDescription></Alert></div></main>;
  }

  const roleCodes = new Set((roles.data ?? []).map((row) => String(row.role_code)));
  const canMutate = [...roleCodes].some((role) => MUTATION_ROLES.has(role));
  return <AntiAbusePanel locale={locale} rules={(rules.data ?? []) as never} cases={(cases.data ?? []) as never} canMutate={canMutate} />;
}
