import { ProviderQuoteWorkbenchPage } from "@/modules/provider/screens/spaces/nested-screens";

export default async function ProviderQuoteDetailPage(props: {
  params: Promise<{ locale: string; quoteId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  return ProviderQuoteWorkbenchPage({ ...props, mode: "create" });
}
