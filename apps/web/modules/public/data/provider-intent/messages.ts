import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { MAX_PROVIDER_SERVICES } from "./model";

const copy = {
  fr: {
    title: "Quels services proposez-vous ?", search: "Rechercher un service", selected: "Services sélectionnés",
    chooseDomain: "Choisissez un domaine", noResult: "Aucun service ne correspond à cette recherche.",
    otherToggle: "Mon service n’est pas répertorié", otherLabel: "Décrivez ce service en quelques mots",
    saved: "Brouillon enregistré sur cet appareil", continue: "Continuer mon inscription", existing: "J’ai déjà un compte",
    limit: `Vous pouvez sélectionner jusqu’à ${MAX_PROVIDER_SERVICES} services.`, empty: "Sélectionnez au moins un service ou décrivez un service non répertorié.",
    storageUnavailable: "Le stockage local est indisponible. Vos choix restent conservés uniquement sur cette page.",
  },
  ar: {
    title: "ما الخدمات التي تقدمها؟", search: "ابحث عن خدمة", selected: "الخدمات المختارة",
    chooseDomain: "اختر مجالاً", noResult: "لا توجد خدمة مطابقة لهذا البحث.",
    otherToggle: "خدمتي غير مدرجة", otherLabel: "صف هذه الخدمة باختصار",
    saved: "تم حفظ المسودة على هذا الجهاز", continue: "متابعة إنشاء الحساب", existing: "لدي حساب بالفعل",
    limit: `يمكنك اختيار ${MAX_PROVIDER_SERVICES} خدمة كحد أقصى.`, empty: "اختر خدمة واحدة على الأقل أو صف خدمة غير مدرجة.",
    storageUnavailable: "التخزين المحلي غير متاح. ستبقى اختياراتك محفوظة في هذه الصفحة فقط.",
  },
} as const;

const servicesGuideCopy = {
  fr: {
    eyebrow: "Domaines & solutions", title: "Trouvez le bon point de départ pour votre besoin.",
    description: "Explorez nos domaines d’intervention pour trouver le bon point de départ. Ce n’est pas un catalogue : chaque domaine vous guide à travers quelques questions. Aucun professionnel n’est contacté sans votre confirmation.",
    search: "Que recherchez-vous ?", searchHint: "Que cherchez-vous à améliorer ?", searchAction: "Trouver le bon parcours",
    domains: "Choisir un domaine", results: "Services correspondants", noResult: "Aucun service ne correspond. Décrivez votre besoin avec vos propres mots.",
    continue: "Décrire ce besoin", custom: "Décrire un autre besoin", serviceAction: "Choisir ce service",
    resultCount: (count: number) => `${count} résultat${count > 1 ? "s" : ""}`,
  },
  ar: {
    eyebrow: "المجالات والخدمات", title: "اعثر على نقطة الانطلاق المناسبة لاحتياجك.",
    description: "استكشف المجالات أو ابحث عن خدمة. يُستخدم اختيارك فقط لإعداد الاحتياج، ولا يتم هنا عرض شراء أو مهنيين.",
    search: "عمّ تبحثون؟", searchHint: "ما الذي ترغبون في تحسينه؟", searchAction: "العثور على المسار المناسب",
    domains: "اختر مجالاً", results: "الخدمات المطابقة", noResult: "لا توجد خدمة مطابقة. صف احتياجك بكلماتك الخاصة.",
    continue: "وصف هذا الاحتياج", custom: "وصف احتياج آخر", serviceAction: "اختيار هذه الخدمة",
    resultCount: (count: number) => `${count} نتيجة`,
  },
} as const;

export function getPublicProviderIntentMessages(locale: Locale) { return copy[locale]; }
export function getPublicServicesGuideMessages(locale: Locale) { return servicesGuideCopy[locale]; }
