import { renderAdminSpacePage } from "@/modules/admin/screens/spaces/render-admin-space";

export default async function AdminProviderFichePage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; organizationId: string }>;
  searchParams: Promise<{ organizationId?: string; q?: string }>;
}) {
  const [{ locale, organizationId }, query] = await Promise.all([params, searchParams]);
  return renderAdminSpacePage({
    locale,
    space: "providers",
    itemId: organizationId,
    organizationId: query.organizationId,
    q: query.q,
  });
}
