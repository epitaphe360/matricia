import type { Locale } from "@/lib/i18n/locale";

const fr = {
  brandLabel: "Matricia — accueil",
  navigationLabel: "Navigation publique",
  menu: "Menu",
  home: "Accueil",
  services: "Services",
  franchise: "Franchise",
  about: "À propos",
  contact: "Contact",
  signIn: "Connexion",
  footerLabel: "Pied de page",
  footerStatement: "Des services professionnels gouvernés, transparents et accessibles en français et en arabe.",
  legalStatement: "Matricia — plateforme de services aux entreprises.",
};

const ar: typeof fr = {
  brandLabel: "ماتريسيا — الصفحة الرئيسية",
  navigationLabel: "التنقل العام",
  menu: "القائمة",
  home: "الرئيسية",
  services: "الخدمات",
  franchise: "الامتياز",
  about: "من نحن",
  contact: "اتصل بنا",
  signIn: "تسجيل الدخول",
  footerLabel: "تذييل الصفحة",
  footerStatement: "خدمات مهنية محكومة وشفافة ومتاحة بالفرنسية والعربية.",
  legalStatement: "ماتريسيا — منصة خدمات للشركات.",
};

export type PublicSiteCopy = typeof fr;

export function getPublicSiteCopy(locale: Locale): PublicSiteCopy {
  return locale === "ar" ? ar : fr;
}
