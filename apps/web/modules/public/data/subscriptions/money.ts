export function formatPublicMoney(value: string, currency: string, locale: "fr" | "ar") {
  const language = locale === "ar" ? "ar-MA" : "fr-MA";
  const formatter = new Intl.NumberFormat(language, { style: "currency", currency });
  const exponent = formatter.resolvedOptions().maximumFractionDigits ?? -1;
  if (!Number.isInteger(exponent) || exponent < 0 || exponent > 3) throw new Error("UNSUPPORTED_CURRENCY_EXPONENT");
  const amount = BigInt(value), scale = BigInt(10) ** BigInt(exponent), major = amount / scale;
  const minor = (amount % scale).toString().padStart(exponent, "0");
  const integer = new Intl.NumberFormat(language, { maximumFractionDigits: 0 }).format(major);
  return formatter.formatToParts(0).map((part) => part.type === "integer" ? integer : part.type === "fraction" ? minor : part.value).join("");
}
