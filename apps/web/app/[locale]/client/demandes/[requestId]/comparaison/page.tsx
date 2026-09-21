import { redirect } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ComparisonAliasPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; requestId: string }>;
  searchParams: Promise<{ rfq?: string; organizationId?: string }>;
}) {
  const [{ locale, requestId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) redirect("/fr/tableau-de-bord");
  const qs = new URLSearchParams();
  if (query.rfq) qs.set("rfq", query.rfq);
  if (query.organizationId) qs.set("organizationId", query.organizationId);
  const suffix = qs.toString() ? `?${qs.toString()}` : "";
  redirect(`/${locale}/client/demandes/${requestId}/offres${suffix}`);
}
