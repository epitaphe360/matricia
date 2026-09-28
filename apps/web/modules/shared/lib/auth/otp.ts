export function normalizeEmail(value: string): string | null {
  const normalized = value.trim().toLowerCase();
  if (normalized.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) return null;
  return normalized;
}

export const emailOtpLength = 8;

export function normalizeOtp(value: string): string | null {
  const normalized = value.replace(/\s/g, "");
  if (!/^\d+$/.test(normalized)) return null;
  return normalized.length === emailOtpLength || normalized.length === 6 ? normalized : null;
}

export function applyOtpDigits(current: string, index: number, raw: string): string {
  const digits = raw.replace(/\D/g, "");
  const chars = Array.from({ length: emailOtpLength }, (_, position) => current[position] ?? "");
  if (!digits) {
    chars[index] = "";
    return chars.join("");
  }
  for (let offset = 0; offset < digits.length && index + offset < emailOtpLength; offset += 1) chars[index + offset] = digits[offset] ?? "";
  return chars.join("");
}
