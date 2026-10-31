import { z } from "zod";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { MarketingDashboard } from "./model";

export type MarketingDimensionLabels = Record<string, string>;

const id = z.string().uuid();
const libraryVersion = z.object({ library_id: id, name_fr: z.string(), name_ar: z.string(), version: z.number().int() });
const service = z.object({ id, current_published_version_id: id.nullable() });
const serviceVersion = z.object({ id, service_id: id, name_fr: z.string(), name_ar: z.string() });
const franchise = z.object({ id, operator_organization_id: id });
const organization = z.object({ id, display_name: z.string() });

function unique(values: Array<string | null>): string[] {
  return Array.from(new Set(values.filter((value): value is string => Boolean(value))));
}

/**
 * Resolves business names for the performance filters so no identifier is shown to users.
 * Reads go through the caller's session: rows hidden by RLS simply keep their ordinal label.
 */
export async function loadMarketingDimensionLabels(dashboard: MarketingDashboard, locale: Locale): Promise<MarketingDimensionLabels> {
  const ar = locale === "ar";
  const labels: MarketingDimensionLabels = {};
  const rows = dashboard.performanceDimensions;
  const libraryIds = unique(rows.map((row) => row.libraryId));
  const serviceIds = unique(rows.map((row) => row.serviceId));
  const franchiseIds = unique(rows.map((row) => row.franchiseId));
  const actorIds = unique(rows.map((row) => row.actorUserId)).sort();
  for (const org of dashboard.organizations) labels[org.id] = org.name;
  const client = await getSupabaseServerClient();
  const [user, libraries, services, franchises] = await Promise.all([
    client.auth.getUser(),
    libraryIds.length ? client.from("catalog_library_versions").select("library_id,name_fr,name_ar,version").in("library_id", libraryIds).order("version", { ascending: false }).limit(300) : Promise.resolve({ data: [], error: null }),
    serviceIds.length ? client.from("catalog_services").select("id,current_published_version_id").in("id", serviceIds).limit(300) : Promise.resolve({ data: [], error: null }),
    franchiseIds.length ? client.from("franchises").select("id,operator_organization_id").in("id", franchiseIds).limit(100) : Promise.resolve({ data: [], error: null }),
  ]);
  const libraryRows = z.array(libraryVersion).safeParse(libraries.error ? [] : libraries.data ?? []);
  if (libraryRows.success) for (const row of libraryRows.data) labels[row.library_id] ??= ar ? row.name_ar : row.name_fr;
  const serviceRows = z.array(service).safeParse(services.error ? [] : services.data ?? []);
  const versionIds = serviceRows.success ? unique(serviceRows.data.map((row) => row.current_published_version_id)) : [];
  if (versionIds.length) {
    const versions = await client.from("catalog_service_versions").select("id,service_id,name_fr,name_ar").in("id", versionIds).limit(300);
    const versionRows = z.array(serviceVersion).safeParse(versions.error ? [] : versions.data ?? []);
    if (versionRows.success) for (const row of versionRows.data) labels[row.service_id] = ar ? row.name_ar : row.name_fr;
  }
  const franchiseRows = z.array(franchise).safeParse(franchises.error ? [] : franchises.data ?? []);
  if (franchiseRows.success && franchiseRows.data.length) {
    const operatorIds = unique(franchiseRows.data.map((row) => row.operator_organization_id)).filter((value) => !labels[value]);
    if (operatorIds.length) {
      const operators = await client.from("organizations").select("id,display_name").in("id", operatorIds).limit(100);
      const operatorRows = z.array(organization).safeParse(operators.error ? [] : operators.data ?? []);
      if (operatorRows.success) for (const row of operatorRows.data) labels[row.id] = row.display_name;
    }
    for (const row of franchiseRows.data) if (labels[row.operator_organization_id]) labels[row.id] = `${ar ? "امتياز" : "Franchise"} ${labels[row.operator_organization_id]}`;
  }
  const currentUser = user.data.user?.id ?? null;
  let member = 0;
  for (const actor of actorIds) {
    if (actor === currentUser) labels[actor] = ar ? "أنتم" : "Vous";
    else { member += 1; labels[actor] = `${ar ? "عضو" : "Membre"} ${member}`; }
  }
  return labels;
}
