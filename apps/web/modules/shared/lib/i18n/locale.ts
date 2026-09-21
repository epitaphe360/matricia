export const supportedLocales = ["fr", "ar"] as const;
export type Locale = (typeof supportedLocales)[number];

export function normalizeLocale(value: string | null | undefined): Locale {
  return value === "ar" ? "ar" : "fr";
}

export function directionFor(locale: Locale): "ltr" | "rtl" {
  return locale === "ar" ? "rtl" : "ltr";
}

export function isLocale(value: string): value is Locale {
  return supportedLocales.includes(value as Locale);
}
