export type PaymentGatewayCode = "DEMO" | "CMI" | "PAYPAL";
export type BillingInterval = "MONTHLY" | "ANNUAL";

export type PaymentIntentRequest = {
  organizationId: string;
  planVersionId: string;
  billingInterval: BillingInterval;
  amountMinor: string;
  currency: string;
  idempotencyKey: string;
  returnUrl: string;
};

export type PaymentIntent = {
  gateway: PaymentGatewayCode;
  providerIntentId: string;
  status: "REQUIRES_CONFIRMATION";
  amountMinor: string;
  currency: string;
  confirmationUrl: string | null;
};

export type VerifiedPaymentEvent = {
  gateway: PaymentGatewayCode;
  providerEventId: string;
  providerIntentId: string;
  eventType: "PAYMENT_SUCCEEDED";
  amountMinor: string;
  currency: string;
  paidAt: string;
  paymentReference: string;
  payloadHash: string;
  signatureFingerprint: string;
};

export interface PaymentGateway {
  readonly code: PaymentGatewayCode;
  createIntent(request: PaymentIntentRequest): Promise<PaymentIntent>;
  verifyWebhook(rawBody: Uint8Array, signatureHeader: string, secret: string): Promise<VerifiedPaymentEvent>;
}

export type PaymentGatewayErrorCode = "INVALID_REQUEST" | "INVALID_AMOUNT" | "INVALID_CURRENCY" | "INVALID_SIGNATURE" | "INVALID_EVENT" | "UNSUPPORTED_EVENT";

export class PaymentGatewayError extends Error {
  constructor(readonly code: PaymentGatewayErrorCode) {
    super(code);
    this.name = "PaymentGatewayError";
  }
}

export function assertPaymentRequest(request: PaymentIntentRequest) {
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!uuid.test(request.organizationId) || !uuid.test(request.planVersionId) || !uuid.test(request.idempotencyKey)) throw new PaymentGatewayError("INVALID_REQUEST");
  if (!/^(?:0|[1-9]\d*)$/.test(request.amountMinor) || BigInt(request.amountMinor) > BigInt("9223372036854775807")) throw new PaymentGatewayError("INVALID_AMOUNT");
  if (!/^[A-Z]{3}$/.test(request.currency)) throw new PaymentGatewayError("INVALID_CURRENCY");
  try { new URL(request.returnUrl); } catch { throw new PaymentGatewayError("INVALID_REQUEST"); }
}
