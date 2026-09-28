import type { UserActionItem } from "@/modules/shared/lib/action-center/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { ClientHomeSnapshot } from "./repository";

export function isDemoClientHomeEnabled() {
  return process.env.MATRICIA_DEMO_ACCESS_ENABLED === "true" && process.env.APP_ENV !== "production";
}

export function isDemoClientOrganization(name: string | null) {
  return Boolean(name && (/^Client · /u.test(name) || /^Client Démo/u.test(name)));
}

export function applyDemoClientHome(input: {
  locale: Locale;
  organizationId: string | null;
  organizationName: string | null;
  selectedQuery: string;
  now: string;
  items: readonly UserActionItem[];
  snapshot: ClientHomeSnapshot;
}): { items: UserActionItem[]; snapshot: ClientHomeSnapshot } {
  return { items: [...input.items], snapshot: input.snapshot };
}
