/** Official administrative regions of Morocco, used as franchise territories. */
export const moroccoRegions = [
  { code: "TANGER_TETOUAN_AL_HOCEIMA", nameFr: "Tanger-Tétouan-Al Hoceïma", nameAr: "طنجة-تطوان-الحسيمة", capitalFr: "Tanger", capitalAr: "طنجة" },
  { code: "ORIENTAL", nameFr: "L'Oriental", nameAr: "الشرق", capitalFr: "Oujda", capitalAr: "وجدة" },
  { code: "FES_MEKNES", nameFr: "Fès-Meknès", nameAr: "فاس-مكناس", capitalFr: "Fès", capitalAr: "فاس" },
  { code: "RABAT_SALE_KENITRA", nameFr: "Rabat-Salé-Kénitra", nameAr: "الرباط-سلا-القنيطرة", capitalFr: "Rabat", capitalAr: "الرباط" },
  { code: "BENI_MELLAL_KHENIFRA", nameFr: "Béni Mellal-Khénifra", nameAr: "بني ملال-خنيفرة", capitalFr: "Béni Mellal", capitalAr: "بني ملال" },
  { code: "CASABLANCA_SETTAT", nameFr: "Casablanca-Settat", nameAr: "الدار البيضاء-سطات", capitalFr: "Casablanca", capitalAr: "الدار البيضاء" },
  { code: "MARRAKECH_SAFI", nameFr: "Marrakech-Safi", nameAr: "مراكش-آسفي", capitalFr: "Marrakech", capitalAr: "مراكش" },
  { code: "DRAA_TAFILALET", nameFr: "Drâa-Tafilalet", nameAr: "درعة-تافيلالت", capitalFr: "Errachidia", capitalAr: "الرشيدية" },
  { code: "SOUSS_MASSA", nameFr: "Souss-Massa", nameAr: "سوس-ماسة", capitalFr: "Agadir", capitalAr: "أكادير" },
  { code: "GUELMIM_OUED_NOUN", nameFr: "Guelmim-Oued Noun", nameAr: "كلميم-واد نون", capitalFr: "Guelmim", capitalAr: "كلميم" },
  { code: "LAAYOUNE_SAKIA_EL_HAMRA", nameFr: "Laâyoune-Sakia El Hamra", nameAr: "العيون-الساقية الحمراء", capitalFr: "Laâyoune", capitalAr: "العيون" },
  { code: "DAKHLA_OUED_ED_DAHAB", nameFr: "Dakhla-Oued Ed-Dahab", nameAr: "الداخلة-وادي الذهب", capitalFr: "Dakhla", capitalAr: "الداخلة" },
] as const;

export type MoroccoRegionCode = (typeof moroccoRegions)[number]["code"];

export function moroccoRegionLabel(code: string, locale: "fr" | "ar"): string {
  const region = moroccoRegions.find((item) => item.code === code);
  if (!region) return code;
  return locale === "ar"
    ? `${region.nameAr} (المقر: ${region.capitalAr})`
    : `${region.nameFr} (chef-lieu : ${region.capitalFr})`;
}
