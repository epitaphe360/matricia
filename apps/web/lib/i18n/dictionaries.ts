import type { Locale } from "./locale";

const dictionaries = {
  fr: {
    auth: {
      eyebrow: "Accès sécurisé",
      title: "Connectez-vous à Matricia",
      description: "Recevez un code à usage unique par courriel. Aucun mot de passe à mémoriser.",
      emailLabel: "Adresse courriel professionnelle",
      emailPlaceholder: "nom@entreprise.ma",
      requestCode: "Recevoir mon code",
      codeLabel: "Code à 6 chiffres",
      verifyCode: "Vérifier et continuer",
      changeEmail: "Utiliser une autre adresse",
      sent: "Si cette adresse est admissible, un code vient d’être envoyé.",
      invalidEmail: "Saisissez une adresse courriel valide.",
      invalidCode: "Le code doit contenir exactement 6 chiffres.",
      genericError: "La connexion n’a pas abouti. Réessayez dans quelques instants.",
      pending: "Vérification en cours…",
      language: "العربية",
    },
    dashboard: {
      eyebrow: "Espace sécurisé",
      title: "Bienvenue dans Matricia",
      session: "Votre session est active et sécurisée.",
      signedInAs: "Connecté en tant que",
      unknownAccount: "Compte authentifié",
      organizationTitle: "Passeport organisation",
      noOrganization: "Aucune organisation active n’est encore rattachée à ce compte.",
      organizationError: "Les organisations ne peuvent pas être chargées pour le moment.",
      organizationStatus: { PENDING: "En attente", ACTIVE: "Active", SUSPENDED: "Suspendue", ARCHIVED: "Archivée", unknown: "Statut indisponible" },
      signOut: "Se déconnecter",
      signOutError: "La déconnexion n’a pas abouti. Votre session reste protégée.",
      language: "العربية",
    },
  },
  ar: {
    auth: {
      eyebrow: "دخول آمن",
      title: "تسجيل الدخول إلى ماتريسيا",
      description: "توصل برمز صالح لمرة واحدة عبر البريد الإلكتروني دون الحاجة إلى كلمة مرور.",
      emailLabel: "البريد الإلكتروني المهني",
      emailPlaceholder: "name@company.ma",
      requestCode: "إرسال الرمز",
      codeLabel: "رمز من 6 أرقام",
      verifyCode: "التحقق والمتابعة",
      changeEmail: "استخدام بريد آخر",
      sent: "إذا كان العنوان مؤهلاً، فقد تم إرسال رمز إليه.",
      invalidEmail: "أدخل عنوان بريد إلكتروني صالحاً.",
      invalidCode: "يجب أن يتكون الرمز من 6 أرقام.",
      genericError: "تعذر تسجيل الدخول. حاول مرة أخرى بعد قليل.",
      pending: "جارٍ التحقق…",
      language: "Français",
    },
    dashboard: {
      eyebrow: "مساحة آمنة",
      title: "مرحباً بك في ماتريسيا",
      session: "جلستك نشطة وآمنة.",
      signedInAs: "تم تسجيل الدخول باسم",
      unknownAccount: "حساب موثّق",
      organizationTitle: "جواز المؤسسة",
      noOrganization: "لا توجد مؤسسة نشطة مرتبطة بهذا الحساب حتى الآن.",
      organizationError: "تعذر تحميل المؤسسات في الوقت الحالي.",
      organizationStatus: { PENDING: "قيد الانتظار", ACTIVE: "نشطة", SUSPENDED: "معلقة", ARCHIVED: "مؤرشفة", unknown: "الحالة غير متاحة" },
      signOut: "تسجيل الخروج",
      signOutError: "تعذر تسجيل الخروج. ما زالت جلستك محمية.",
      language: "Français",
    },
  },
} as const;

export function getDictionary(locale: Locale) {
  return dictionaries[locale];
}
