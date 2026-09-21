import type { Locale } from "@/modules/shared/lib/i18n/locale";

const fr = {
  brandLabel: "Matricia — accueil",
  navigationLabel: "Navigation publique",
  menu: "Menu",
  home: "Accueil",
  services: "Diagnostic",
  companies: "Entreprises",
  how: "Comment ça marche",
  plans: "Abonnements",
  franchise: "Franchise",
  about: "À propos",
  contact: "Contact",
  signIn: "Connexion",
  footerLabel: "Pied de page",
  footerStatement: "Des expertises qui font avancer le Maroc, en français et en arabe.",
  legalStatement: "Matricia — des entreprises plus fortes, un Maroc plus ambitieux.",
  legalMentions: "Mentions légales",
  legalPrivacy: "Confidentialité",
  legalTerms: "Conditions d’utilisation",
  legalCookies: "Cookies",
};

const ar: typeof fr = {
  brandLabel: "ماتريسيا — الصفحة الرئيسية",
  navigationLabel: "التنقل العام",
  menu: "القائمة",
  home: "الرئيسية",
  services: "التقييم",
  companies: "المؤسسات",
  how: "كيف تعمل المنصة",
  plans: "الاشتراكات",
  franchise: "الامتياز",
  about: "من نحن",
  contact: "اتصل بنا",
  signIn: "تسجيل الدخول",
  footerLabel: "تذييل الصفحة",
  footerStatement: "خدمات مهنية محكومة وشفافة ومتاحة بالفرنسية والعربية.",
  legalStatement: "ماتريسيا — منصة خدمات للشركات.",
  legalMentions: "الإشعارات القانونية",
  legalPrivacy: "الخصوصية",
  legalTerms: "شروط الاستخدام",
  legalCookies: "ملفات تعريف الارتباط",
};

export type PublicSiteCopy = typeof fr;

export function getPublicSiteCopy(locale: Locale): PublicSiteCopy {
  return locale === "ar" ? ar : fr;
}
