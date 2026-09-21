import { renderProviderLedgerPage } from "@/modules/provider/screens/facturation/ledger-route";

export default async function ProviderPreStatementPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  return renderProviderLedgerPage("pre-releve", params, searchParams);
}
