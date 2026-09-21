import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getDisputeMessages, type DisputeMessages } from "@/modules/client/screens/litiges/messages";

const fr = {
  title: "Incidents et litiges",
  intro: "Répondez aux dossiers ouverts sur vos missions. La médiation reste humaine ; aucune décision automatique n’est appliquée.",
} as const;

const ar = {
  title: "الحوادث والنزاعات",
  intro: "ردّوا على الملفات المفتوحة في مهامكم. تبقى الوساطة بشرية ولا يُطبَّق أي قرار آلي.",
} as const;

export function getProviderDisputeMessages(locale: Locale): DisputeMessages & { title: string; intro: string } {
  return { ...getDisputeMessages(locale), ...(locale === "ar" ? ar : fr) };
}
