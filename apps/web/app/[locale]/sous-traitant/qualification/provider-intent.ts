import type { Locale } from "@/lib/i18n/locale";

export function readProviderIntent(storage: Pick<Storage,"getItem">,locale:Locale) {
  try { return (storage.getItem("matricia.provider-intent")??storage.getItem(`matricia.provider-intent.${locale}`)??"").slice(0,2000); }
  catch { return ""; }
}

export function clearProviderIntent(storage: Pick<Storage,"removeItem">,locale:Locale) {
  try { storage.removeItem("matricia.provider-intent");storage.removeItem(`matricia.provider-intent.${locale}`);return true; }
  catch { return false; }
}
