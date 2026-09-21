import { redirect } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { notFound } from "next/navigation";

export default async function AdminGovernanceRedirect({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const q = query.organizationId ? `?organizationId=${encodeURIComponent(query.organizationId)}` : "";
  redirect(`/${locale}/administration/gouvernance${q}`);
}
