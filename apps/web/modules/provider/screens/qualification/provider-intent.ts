import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { parseProviderIntentDraft, PROVIDER_INTENT_KEY, PROVIDER_INTENT_LEGACY_KEY, type ProviderIntentDraft } from "@/modules/public/data/provider-intent/model";

export type RecoveredProviderIntent = Pick<ProviderIntentDraft,"serviceCodes"|"otherService">;

export function readStructuredProviderIntent(storage: Pick<Storage,"getItem">): RecoveredProviderIntent | null {
  try {
    const draft=parseProviderIntentDraft(storage.getItem(PROVIDER_INTENT_KEY));
    return draft?{serviceCodes:draft.serviceCodes,otherService:draft.otherService}:null;
  } catch { return null; }
}

export function readProviderIntent(storage: Pick<Storage,"getItem">,locale:Locale) {
  try { return (storage.getItem("matricia.provider-intent")??storage.getItem(`matricia.provider-intent.${locale}`)??"").slice(0,2000); }
  catch { return ""; }
}

export function clearProviderIntent(storage: Pick<Storage,"removeItem">,locale:Locale) {
  try { storage.removeItem(PROVIDER_INTENT_KEY);storage.removeItem(PROVIDER_INTENT_LEGACY_KEY);storage.removeItem(`matricia.provider-intent.${locale}`);return true; }
  catch { return false; }
}
