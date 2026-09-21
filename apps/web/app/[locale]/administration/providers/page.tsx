import { renderAdminSpacePage } from "@/modules/admin/screens/spaces/render-admin-space";

export default async function AdminProvidersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string; q?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  return renderAdminSpacePage({ locale, space: "providers", organizationId: query.organizationId, q: query.q });
}
