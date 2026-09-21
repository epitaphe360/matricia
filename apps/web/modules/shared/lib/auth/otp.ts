export function normalizeEmail(value: string): string | null {
  const normalized = value.trim().toLowerCase();
  if (normalized.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) return null;
  return normalized;
}

export function normalizeOtp(value: string): string | null {
  const normalized = value.replace(/\s/g, "");
  return /^\d{6}$/.test(normalized) ? normalized : null;
}
