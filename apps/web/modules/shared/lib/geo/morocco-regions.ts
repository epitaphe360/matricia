/** Official administrative regions of Morocco, shared by franchise territories and request matching. */
export const moroccoRegions = [
  { code: "TANGER_TETOUAN_AL_HOCEIMA", nameFr: "Tanger-Tétouan-Al Hoceïma", nameAr: "طنجة-تطوان-الحسيمة", capitalFr: "Tanger", capitalAr: "طنجة", cities: ["tanger", "tetouan", "al hoceima", "larache", "chefchaouen", "fnideq", "ksar el kebir"] },
  { code: "ORIENTAL", nameFr: "L'Oriental", nameAr: "الشرق", capitalFr: "Oujda", capitalAr: "وجدة", cities: ["oujda", "nador", "berkane", "taourirt", "jerada", "figuig"] },
  { code: "FES_MEKNES", nameFr: "Fès-Meknès", nameAr: "فاس-مكناس", capitalFr: "Fès", capitalAr: "فاس", cities: ["fes", "meknes", "taza", "ifrane", "sefrou", "el hajeb"] },
  { code: "RABAT_SALE_KENITRA", nameFr: "Rabat-Salé-Kénitra", nameAr: "الرباط-سلا-القنيطرة", capitalFr: "Rabat", capitalAr: "الرباط", cities: ["rabat", "sale", "kenitra", "temara", "skhirat", "khemisset", "sidi kacem"] },
  { code: "BENI_MELLAL_KHENIFRA", nameFr: "Béni Mellal-Khénifra", nameAr: "بني ملال-خنيفرة", capitalFr: "Béni Mellal", capitalAr: "بني ملال", cities: ["beni mellal", "khenifra", "khouribga", "fquih ben salah", "azilal"] },
  { code: "CASABLANCA_SETTAT", nameFr: "Casablanca-Settat", nameAr: "الدار البيضاء-سطات", capitalFr: "Casablanca", capitalAr: "الدار البيضاء", cities: ["casablanca", "settat", "mohammedia", "el jadida", "berrechid", "benslimane", "mediouna", "nouaceur", "bouskoura"] },
  { code: "MARRAKECH_SAFI", nameFr: "Marrakech-Safi", nameAr: "مراكش-آسفي", capitalFr: "Marrakech", capitalAr: "مراكش", cities: ["marrakech", "safi", "essaouira", "el kelaa des sraghna", "youssoufia", "chichaoua"] },
  { code: "DRAA_TAFILALET", nameFr: "Drâa-Tafilalet", nameAr: "درعة-تافيلالت", capitalFr: "Errachidia", capitalAr: "الرشيدية", cities: ["errachidia", "ouarzazate", "zagora", "tinghir", "midelt"] },
  { code: "SOUSS_MASSA", nameFr: "Souss-Massa", nameAr: "سوس-ماسة", capitalFr: "Agadir", capitalAr: "أكادير", cities: ["agadir", "inezgane", "taroudant", "tiznit", "ait melloul"] },
  { code: "GUELMIM_OUED_NOUN", nameFr: "Guelmim-Oued Noun", nameAr: "كلميم-واد نون", capitalFr: "Guelmim", capitalAr: "كلميم", cities: ["guelmim", "tan-tan", "sidi ifni", "assa"] },
  { code: "LAAYOUNE_SAKIA_EL_HAMRA", nameFr: "Laâyoune-Sakia El Hamra", nameAr: "العيون-الساقية الحمراء", capitalFr: "Laâyoune", capitalAr: "العيون", cities: ["laayoune", "boujdour", "tarfaya", "smara", "es-semara"] },
  { code: "DAKHLA_OUED_ED_DAHAB", nameFr: "Dakhla-Oued Ed-Dahab", nameAr: "الداخلة-وادي الذهب", capitalFr: "Dakhla", capitalAr: "الداخلة", cities: ["dakhla", "aousserd"] },
] as const;

export type MoroccoRegionCode = (typeof moroccoRegions)[number]["code"];

export function isMoroccoRegionCode(value: string): value is MoroccoRegionCode {
  return moroccoRegions.some((region) => region.code === value);
}

export function moroccoRegionLabel(code: string, locale: "fr" | "ar"): string {
  const region = moroccoRegions.find((item) => item.code === code);
  if (!region) return code;
  return locale === "ar"
    ? `${region.nameAr} (المقر: ${region.capitalAr})`
    : `${region.nameFr} (chef-lieu : ${region.capitalFr})`;
}

function normalize(text: string): string {
  return text.normalize("NFD").replace(/[\u0300-\u036f]/gu, "").replace(/[^\p{L}\p{N}\p{M}]+/gu, " ").trim().toLowerCase();
}

/** Resolves a free-text location ("Casablanca, Maarif", "الرباط") to a region code, or "" when ambiguous or unknown. */
export function regionCodeFromText(text: string): MoroccoRegionCode | "" {
  const raw = text.trim();
  if (!raw) return "";
  const upper = raw.toUpperCase();
  if (isMoroccoRegionCode(upper)) return upper;
  const value = ` ${normalize(raw)} `;
  const matches = moroccoRegions.filter((region) =>
    [region.nameFr, region.capitalFr, ...region.cities].some((name) => value.includes(` ${normalize(name)} `))
    || raw.includes(region.nameAr)
    || raw.includes(region.capitalAr),
  );
  return matches.length === 1 ? matches[0]!.code : "";
}
