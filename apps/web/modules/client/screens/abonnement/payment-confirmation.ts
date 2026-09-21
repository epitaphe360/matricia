export const paypalCaptureStorageKey = "matricia.paypal.capture.v1";

export type PaymentIntentResponse = {
  paymentIntentId: string;
  providerIntentId: string;
  gateway: "DEMO" | "CMI" | "PAYPAL";
  status: "REQUIRES_CONFIRMATION";
  confirmation: null | { method: "GET"; url: string } | { method: "POST"; url: string; fields: Record<string, string> };
};

export function parsePaymentIntent(value: unknown): PaymentIntentResponse | null {
  if (!isRecord(value) || typeof value.paymentIntentId !== "string" || typeof value.providerIntentId !== "string"
    || !["DEMO", "CMI", "PAYPAL"].includes(String(value.gateway)) || value.status !== "REQUIRES_CONFIRMATION") return null;
  if (value.confirmation === null) return value as PaymentIntentResponse;
  if (!isRecord(value.confirmation) || typeof value.confirmation.url !== "string") return null;
  if (!isSafeProviderUrl(value.confirmation.url)) return null;
  if (value.confirmation.method === "GET") return value as PaymentIntentResponse;
  if (value.confirmation.method !== "POST" || !isRecord(value.confirmation.fields)
    || Object.entries(value.confirmation.fields).some(([key, field]) => !/^[A-Za-z0-9_.-]{1,80}$/u.test(key) || typeof field !== "string" || field.length > 4_096)) return null;
  return value as PaymentIntentResponse;
}

export function parsePayPalCaptureReturn(search: string, stored: string | null): { paymentIntentId: string } | null {
  if (!stored) return null;
  const parameters = new URLSearchParams(search);
  if (parameters.get("payment") !== "pending" || !parameters.get("PayerID")) return null;
  try {
    const value: unknown = JSON.parse(stored);
    if (!isRecord(value) || typeof value.paymentIntentId !== "string" || typeof value.providerIntentId !== "string"
      || parameters.get("token") !== value.providerIntentId) return null;
    return { paymentIntentId: value.paymentIntentId };
  } catch {
    return null;
  }
}

function isSafeProviderUrl(value: string): boolean {
  try { return new URL(value).protocol === "https:"; } catch { return false; }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
