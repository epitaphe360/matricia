import { ProviderQuoteWorkbenchPage } from "@/modules/provider/screens/spaces/nested-screens";

export default async function ProviderNewQuotePage(props: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale } = await props.params;
  return ProviderQuoteWorkbenchPage({
    params: Promise.resolve({ locale, quoteId: "nouveau" }),
    searchParams: props.searchParams,
    mode: "create",
  });
}
