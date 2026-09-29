import { z } from "zod";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getPublicSiteUrl } from "@/modules/shared/lib/seo/metadata";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { buildMarketingBrandDefaults, type MarketingBrandDefaults } from "./brand-defaults-model";

const id = z.string().uuid();
const orgRow = z.object({ display_name: z.string() });
const kitRow = z.object({ current_version_id: id.nullable() });
const versionRow = z.object({ payload: z.record(z.string(), z.unknown()) });
const serviceRow = z.object({ service_id: id });
const catalogRow = z.object({ current_published_version_id: id.nullable() });
const nameRow = z.object({ name_fr: z.string(), name_ar: z.string() });

function siteOrigin(): string | null {
  try {
    return getPublicSiteUrl().origin;
  } catch {
    return null;
  }
}

export async function loadMarketingBrandDefaults(organizationId: string, locale: Locale, extraTopics: string[] = []): Promise<MarketingBrandDefaults | null> {
  if (!id.safeParse(organizationId).success) return null;
  const client = await getSupabaseServerClient();
  const [organization, kit, services] = await Promise.all([
    client.from("organizations").select("display_name").eq("id", organizationId).maybeSingle(),
    client.from("brand_kits").select("current_version_id").eq("organization_id", organizationId).maybeSingle(),
    client.from("provider_services").select("service_id").eq("provider_organization_id", organizationId).limit(20),
  ]);
  const org = orgRow.safeParse(organization.data);
  if (organization.error || !org.success) return null;
  let payload: Record<string, unknown> | null = null;
  const kitValue = kitRow.safeParse(kit.data);
  if (!kit.error && kitValue.success && kitValue.data.current_version_id) {
    const version = await client.from("brand_kit_versions").select("payload").eq("id", kitValue.data.current_version_id).maybeSingle();
    const parsed = versionRow.safeParse(version.data);
    if (!version.error && parsed.success) payload = parsed.data.payload;
  }
  const topics: string[] = [...extraTopics];
  const serviceIds = z.array(serviceRow).safeParse(services.data ?? []);
  if (!payload && !services.error && serviceIds.success && serviceIds.data.length > 0) {
    const catalog = await client.from("catalog_services").select("current_published_version_id").in("id", serviceIds.data.map((value) => value.service_id)).limit(20);
    const versionIds = z.array(catalogRow).safeParse(catalog.data ?? []);
    const published = versionIds.success ? versionIds.data.flatMap((value) => (value.current_published_version_id ? [value.current_published_version_id] : [])) : [];
    if (!catalog.error && published.length > 0) {
      const names = await client.from("catalog_service_versions").select("name_fr,name_ar").in("id", published).limit(5);
      const parsed = z.array(nameRow).safeParse(names.data ?? []);
      if (!names.error && parsed.success) topics.push(...parsed.data.map((value) => (locale === "ar" ? value.name_ar : value.name_fr)));
    }
  }
  return buildMarketingBrandDefaults({ locale, displayName: org.data.display_name, payload, topics, siteOrigin: siteOrigin() });
}
