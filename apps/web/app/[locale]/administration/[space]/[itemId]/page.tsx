import { renderAdminSpacePage } from "@/modules/admin/screens/spaces/render-admin-space";

export default async function AdminSpaceItemPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; space: string; itemId: string }>;
  searchParams: Promise<{ organizationId?: string; q?: string }>;
}) {
  const [{ locale, space, itemId }, query] = await Promise.all([params, searchParams]);
  return renderAdminSpacePage({ locale, space, itemId, organizationId: query.organizationId, q: query.q });
}
