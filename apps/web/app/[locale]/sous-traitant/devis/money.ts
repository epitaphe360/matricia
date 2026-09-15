function normalizeDigits(value: string): string {
  return value.replace(/[٠-٩]/gu, (digit) => String("٠١٢٣٤٥٦٧٨٩".indexOf(digit))).replace(/[۰-۹]/gu, (digit) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(digit)));
}

/** Converts a user-facing amount to exact minor units without binary floating point. */
export function parseMoneyToMinor(value: string, currency: string): string | null {
  let exponent: number;
  try {
    const options = new Intl.NumberFormat("fr-MA", { style: "currency", currency }).resolvedOptions();
    exponent = options.maximumFractionDigits ?? options.minimumFractionDigits ?? -1;
  } catch { return null; }
  if (!Number.isInteger(exponent) || exponent < 0 || exponent > 3) return null;
  let normalized = normalizeDigits(value).trim().replace(/\u00a0|\u202f/gu, " ").replace(/٬/gu, " ").replace(/٫/gu, ",");
  if (!/^[0-9 .,]+$/u.test(normalized)) return null;
  if (normalized.includes(" ")) {
    const chunks = normalized.split(/[ ]+/u);
    if (!/^\d{1,3}$/u.test(chunks[0] ?? "") || chunks.slice(1).some((chunk) => !/^\d{3}(?:[.,]\d+)?$/u.test(chunk))) return null;
    normalized = chunks.join("");
  }
  const separators = [...normalized.matchAll(/[.,]/gu)];
  if (separators.length > 1) return null;
  const separator = separators[0]; let whole = normalized; let fraction = "";
  if (separator) {
    const index = separator.index ?? -1; whole = normalized.slice(0, index); fraction = normalized.slice(index + 1);
    if (fraction.length > exponent || (fraction.length === 3 && exponent !== 3)) return null;
  }
  if (!/^\d{1,15}$/u.test(whole) || (fraction && !/^\d+$/u.test(fraction))) return null;
  const minor = BigInt(whole) * (BigInt(10) ** BigInt(exponent)) + BigInt((fraction || "0").padEnd(exponent, "0"));
  return minor.toString().length <= 18 ? minor.toString() : null;
}

export function minorToMoneyInput(value: string, currency: string): string {
  let exponent = 2;
  try {
    const options = new Intl.NumberFormat("fr-MA", { style: "currency", currency }).resolvedOptions();
    exponent = options.maximumFractionDigits ?? options.minimumFractionDigits ?? 2;
  } catch { return value; }
  const scale = BigInt(10) ** BigInt(exponent), amount = BigInt(value), whole = amount / scale;
  if (exponent === 0) return whole.toString();
  return `${whole}.${(amount % scale).toString().padStart(exponent, "0")}`;
}
