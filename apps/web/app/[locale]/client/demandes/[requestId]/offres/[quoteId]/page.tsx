import { notFound, redirect } from "next/navigation";
import { ClientOfferDetailView } from "@/modules/client/screens/demandes/offer-detail";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { loadClientOfferDetail } from "@/modules/client/data/rfq/quote-detail-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";

export default async function OfferDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; requestId: string; quoteId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale, requestId, quoteId }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const selectedOrganizationId = typeof query.organizationId === "string" ? query.organizationId : null;
  const selectedQuery = selectedOrganizationId ? `?organizationId=${encodeURIComponent(selectedOrganizationId)}` : "";
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  const organizationName = selectedOrganizationId
    ? (await client.from("organizations").select("display_name").eq("id", selectedOrganizationId).limit(1)).data?.[0]?.display_name ?? null
    : null;
  const result = await loadClientOfferDetail({
    locale,
    requestId,
    quoteId,
    organizationQuery: selectedQuery,
    organizationName,
  });
  if (result.status === "unauthenticated") redirect(`/${locale}/connexion`);
  if (result.status === "not_found") notFound();
  if (result.status === "error") throw new Error("OFFER_DETAIL_UNAVAILABLE");
  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={selectedQuery}
      selectedOrganizationId={selectedOrganizationId}
      userEmail={auth.user?.email ?? null}
      active="requests"
    >
      <ClientOfferDetailView locale={locale} selectedQuery={selectedQuery} detail={result.value} />
    </ClientAppShell>
  );
}
