import type { Locale } from "@/lib/i18n/locale";

const libraries = [
  { code: "IT", nameFr: "Informatique, cybersécurité et data", nameAr: "تكنولوجيا المعلومات والأمن السيبراني والبيانات", serviceCount: 20 },
  { code: "COM", nameFr: "Communication, marketing et création", nameAr: "التواصل والتسويق والإبداع", serviceCount: 20 },
  { code: "ACC", nameFr: "Comptabilité, fiscalité et finance", nameAr: "المحاسبة والضرائب والمالية", serviceCount: 20 },
  { code: "LEGAL", nameFr: "Juridique, conformité et gouvernance", nameAr: "الشؤون القانونية والامتثال والحوكمة", serviceCount: 20 },
  { code: "HR", nameFr: "Ressources humaines et formation", nameAr: "الموارد البشرية والتكوين", serviceCount: 20 },
  { code: "INS", nameFr: "Assurance et gestion des risques", nameAr: "التأمين وإدارة المخاطر", serviceCount: 20 },
  { code: "LOG", nameFr: "Achats, logistique et supply chain", nameAr: "المشتريات واللوجستيك وسلسلة الإمداد", serviceCount: 20 },
  { code: "BTP", nameFr: "BTP, immobilier et maintenance", nameAr: "البناء والعقار والصيانة", serviceCount: 20 },
  { code: "QHSE", nameFr: "Qualité, HSE et certifications", nameAr: "الجودة والصحة والسلامة والبيئة والشهادات", serviceCount: 20 },
  { code: "SALES", nameFr: "Commercial, vente et expérience client", nameAr: "التجارة والمبيعات وتجربة العملاء", serviceCount: 20 },
] as const;

export const PUBLIC_CATALOGUE_TOTALS = Object.freeze({ libraryCount: 10, serviceCount: 200 });

export function getStaticPublicCatalogue(locale: Locale) {
  return {
    ...PUBLIC_CATALOGUE_TOTALS,
    libraries: libraries.map(library => ({ code: library.code, name: locale === "ar" ? library.nameAr : library.nameFr, serviceCount: library.serviceCount })),
  };
}
