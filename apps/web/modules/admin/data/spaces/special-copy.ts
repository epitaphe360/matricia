import type { Locale } from "@/modules/shared/lib/i18n/locale";

function t(locale: Locale, fr: string, ar: string) {
  return locale === "ar" ? ar : fr;
}

export function specialBoardCopy(locale: Locale, kind: "consultation" | "reuse" | "preferences") {
  if (kind === "consultation") {
    return {
      title: t(locale, "Préparer et envoyer une consultation", "تحضير وإرسال استشارة"),
      lead: t(locale, "Sélectionnez les prestataires, personnalisez le contenu partagé, vos questions et les conditions, puis envoyez la consultation.", "اختاروا مقدمي الخدمات وخصّصوا المحتوى المشترك والأسئلة والشروط ثم أرسلوا الاستشارة."),
      crumb: t(locale, "Nouvelle consultation", "استشارة جديدة"),
    };
  }
  if (kind === "reuse") {
    return {
      title: t(locale, "Réutilisation et partage sécurisé", "إعادة الاستخدام والمشاركة الآمنة"),
      lead: t(locale, "Associez un document existant à un autre élément sans dupliquer le fichier, en respectant les règles de sécurité et de conformité.", "اربطوا وثيقة قائمة بعنصر آخر دون تكرار الملف مع احترام قواعد الأمن والامتثال."),
      crumb: t(locale, "Réutilisation", "إعادة استخدام"),
    };
  }
  return {
    title: t(locale, "Centre de notifications et préférences", "مركز الإشعارات والتفضيلات"),
    lead: t(locale, "Configurez les règles d’envoi, les modèles, les canaux et les préférences. Suivez la file d’envoi, les échecs et l’historique.", "اضبطوا قواعد الإرسال والقوالب والقنوات والتفضيلات. تابعوا طابور الإرسال والإخفاقات والسجل."),
    crumb: t(locale, "Préférences", "التفضيلات"),
  };
}
