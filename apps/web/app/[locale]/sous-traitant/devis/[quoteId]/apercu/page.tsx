import { ProviderQuotePreviewPage } from "@/modules/provider/screens/spaces/nested-screens";

export default async function ProviderQuotePreviewRoute(props: {
  params: Promise<{ locale: string; quoteId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  return ProviderQuotePreviewPage(props);
}
