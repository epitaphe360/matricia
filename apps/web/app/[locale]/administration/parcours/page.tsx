import { notFound, redirect } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function AdminParcoursRedirect({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const q = query.organizationId ? `?organizationId=${encodeURIComponent(query.organizationId)}` : "";
  redirect(`/${locale}/administration/diagnostics${q}`);
}
