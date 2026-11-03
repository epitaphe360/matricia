import type { Locale } from "@/modules/shared/lib/i18n/locale";

/** Only same-site journeys that resume after the Client organization exists; anything else is dropped. */
export function organizationReturnPath(locale: Locale, value: string | undefined): string | null {
  const allowed = [`/${locale}/diagnostic?reprendre=enregistrer`];
  if(value && new RegExp(`^/${locale}/invitation/[A-Z0-9][A-Z0-9_-]{7,63}$`, "u").test(value)) return value;
  return value && allowed.includes(value) ? value : null;
}
