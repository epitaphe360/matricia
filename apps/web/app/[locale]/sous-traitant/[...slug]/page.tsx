import { notFound } from "next/navigation";
import { resolveProviderNestedView } from "@/modules/provider/data/spaces/nested-views";
import { ProviderNestedPage } from "@/modules/provider/screens/spaces/nested-screens";
import { providerFallbackPath } from "@/modules/shared/lib/connected-space/nested-fallbacks";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ProviderNestedFallbackPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; slug: string[] }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale, slug } = await params;
  if (!isLocale(locale) || !slug?.length) notFound();
  const nested = resolveProviderNestedView(slug);
  const destination = providerFallbackPath(slug);
  if (!nested && destination === slug.join("/")) notFound();
  return ProviderNestedPage({ params: Promise.resolve({ locale, slug }), searchParams });
}
