import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { cn } from "@/lib/utils";
import { ClonePanel, type CloneChoices } from "./clone-panel";

const MUTATION_ROLES = new Set(["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER"]);

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const ar = locale === "ar", client = await getSupabaseServerClient();
  const { data: auth, error: authError } = await client.auth.getUser();
  if (authError || !auth.user) redirect(`/${locale}/connexion`);
  const [roles, questionnaireVersions, releases, contractVersions, clauseVersions, checklistTemplates, serviceVersions, organizations] = await Promise.all([
    client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).limit(20),
    client.from("questionnaire_versions").select("id,library_id,version,status,title_fr,title_ar").in("status", ["DRAFT", "LOCAL_TEST", "FRANCHISE_REVIEW", "CENTRAL_REVIEW", "APPROVED", "PUBLISHED"]).order("created_at", { ascending: false }).limit(200),
    client.from("catalog_releases").select("id,library_id,release_key,status").in("status", ["DRAFT", "IN_REVIEW", "APPROVED"]).order("created_at", { ascending: false }).limit(100),
    client.from("contract_versions").select("id,contract_id,version").order("created_at", { ascending: false }).limit(200),
    client.from("contract_clause_set_versions").select("id,version").order("created_at", { ascending: false }).limit(200),
    client.from("service_checklist_templates").select("id,service_version_id,version").order("created_at", { ascending: false }).limit(200),
    client.from("catalog_service_versions").select("id,version,status,name_fr,name_ar").in("status", ["DRAFT", "IN_REVIEW", "APPROVED", "PUBLISHED"]).order("created_at", { ascending: false }).limit(200),
    client.from("organizations").select("id,display_name").eq("status", "ACTIVE").order("display_name").limit(200),
  ]);
  const failed = [roles, questionnaireVersions, releases, contractVersions, clauseVersions, checklistTemplates, serviceVersions, organizations].find((query) => query.error)?.error;
  if (failed) return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-7xl"><Alert variant="destructive"><AlertTitle>{ar ? "تعذر تحميل خيارات الاستنساخ" : "Impossible de charger les choix de clonage"}</AlertTitle><AlertDescription>{failed.code === "42501" ? (ar ? "لا يسمح دورك بالوصول إلى هذه البيانات." : "Votre rôle ne permet pas d’accéder à ces données.") : (ar ? "أعد المحاولة لاحقاً؛ لم يتم تنفيذ أي استنساخ." : "Réessayez plus tard ; aucun clonage n’a été exécuté.")}</AlertDescription></Alert></div></main>;
  const roleCodes = new Set((roles.data ?? []).map((row) => String(row.role_code)));
  const canMutate = [...roleCodes].some((role) => MUTATION_ROLES.has(role));
  const serviceNames = new Map((serviceVersions.data ?? []).map((row) => [String(row.id), locale === "ar" ? String(row.name_ar) : String(row.name_fr)]));
  const choices: CloneChoices = {
    questionnaires: (questionnaireVersions.data ?? []).map((row) => ({ value: String(row.id), label: `${locale === "ar" ? row.title_ar : row.title_fr} · v${row.version} · ${row.status}`, scope: String(row.library_id) })),
    releases: (releases.data ?? []).map((row) => ({ value: String(row.id), label: `${row.release_key} · ${row.status}`, scope: String(row.library_id) })),
    contracts: (contractVersions.data ?? []).map((row) => ({ value: String(row.id), label: `${ar ? "عقد" : "Contrat"} ${String(row.contract_id).slice(0, 8)} · v${row.version}` })),
    clauseSets: (clauseVersions.data ?? []).map((row) => ({ value: String(row.id), label: `${ar ? "مجموعة بنود" : "Jeu de clauses"} · v${row.version}` })),
    checklists: (checklistTemplates.data ?? []).map((row) => ({ value: String(row.id), label: `${serviceNames.get(String(row.service_version_id)) ?? (ar ? "خدمة" : "Service")} · ${ar ? "قائمة" : "checklist"} v${row.version}` })),
    services: (serviceVersions.data ?? []).map((row) => ({ value: String(row.id), label: `${locale === "ar" ? row.name_ar : row.name_fr} · v${row.version} · ${row.status}` })),
    organizations: (organizations.data ?? []).map((row) => ({ value: String(row.id), label: String(row.display_name) })),
  };
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-7xl space-y-7"><nav><Link href={`/${locale}/tableau-de-bord`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{ar ? "لوحة التحكم" : "Tableau de bord"}</Link></nav><header><h1 className="text-3xl font-semibold">{ar ? "استنساخ المحتوى مع المصدر" : "Clonage de contenu avec provenance"}</h1><p className="mt-3 text-muted-foreground">{ar ? "اختر محتوى موجوداً ووجهته. يتحقق الخادم من الصلاحيات والمصدر قبل إنشاء إصدار جديد." : "Choisissez un contenu existant et sa destination. Le serveur revalide les droits et la provenance avant de créer une nouvelle version."}</p></header><ClonePanel locale={locale} keys={[randomUUID(), randomUUID(), randomUUID()]} choices={choices} canMutate={canMutate} /></div></main>;
}
