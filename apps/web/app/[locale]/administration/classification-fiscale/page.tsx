import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { AdminModulePage } from "@/modules/admin/ui/admin-module-page";
import { ServiceTaxConsole } from "@/modules/admin/screens/service-tax/service-tax-console";

export default async function ServiceTaxMappingPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) redirect(connexionHref(locale, { next: `/${locale}/administration/classification-fiscale` }));
  return (
    <AdminModulePage locale={locale} active="finance" path="classification-fiscale"
      title={locale === "ar" ? "التصنيف الضريبي للخدمات" : "Classification fiscale des services"}
      lead={locale === "ar" ? "ربط خدمة منشورة بفئة ضريبية معتمدة بقرار مستقل ومؤرخ، دون تغيير الطلبات أو العروض السابقة." : "Associer un service publié à une catégorie fiscale validée par une décision indépendante et datée, en conservant les demandes et devis antérieurs."}>
      <ServiceTaxConsole locale={locale} />
    </AdminModulePage>
  );
}
