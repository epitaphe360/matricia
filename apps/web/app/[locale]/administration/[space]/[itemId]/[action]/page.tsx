import { renderAdminSpacePage } from "@/modules/admin/screens/spaces/render-admin-space";

export default async function AdminSpaceActionPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; space: string; itemId: string; action: string }>;
  searchParams: Promise<{ organizationId?: string; q?: string }>;
}) {
  const [{ locale, space, itemId, action }, query] = await Promise.all([params, searchParams]);
  return renderAdminSpacePage({ locale, space, itemId, action, organizationId: query.organizationId, q: query.q });
}
