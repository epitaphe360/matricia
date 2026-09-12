import { createPublicKey, createVerify } from "node:crypto";
import {
  assertPaymentRequest,
  decimalToMinor,
  minorToDecimal,
  PaymentGatewayError,
  type PaymentGateway,
  type PaymentCaptureGateway,
  type PaymentIntent,
  type PaymentIntentRequest,
  type PaymentWebhookVerifier,
  type VerifiedPaymentEvent,
} from "./contracts.js";
import { sha256Hex } from "./webhook.js";
import { assertGatewayCurrency, isSupportedTwoDecimalCurrency } from "./currency-exponents.js";

export type PayPalOrderClient = {
  createOrder(input: {
    requestId: string;
    invoiceId: string;
    amount: string;
    currency: string;
    returnUrl: string;
  }): Promise<unknown>;
  captureOrder(input: { orderId: string; requestId: string }): Promise<unknown>;
};

export type PayPalGatewayConfig = {
  webhookId: string;
  certificateUrl: string;
  certificatePem: string;
  allowedCurrencies: ReadonlySet<string>;
};

export class PayPalPaymentGateway implements PaymentGateway, PaymentCaptureGateway, PaymentWebhookVerifier {
  readonly code = "PAYPAL" as const;
  private readonly certificateUrl: string;

  constructor(private readonly orderClient: PayPalOrderClient, private readonly config: PayPalGatewayConfig) {
    let certificateUrl: URL;
    try {
      certificateUrl = new URL(config.certificateUrl);
      createPublicKey(config.certificatePem);
    } catch {
      throw new PaymentGatewayError("CONFIGURATION_INVALID");
    }
    if (
      certificateUrl.protocol !== "https:" ||
      !isPayPalApiHost(certificateUrl.hostname) ||
      !certificateUrl.pathname.startsWith("/v1/notifications/certs/") ||
      !/^[A-Za-z0-9_-]{6,50}$/u.test(config.webhookId) ||
      config.allowedCurrencies.size === 0 ||
      [...config.allowedCurrencies].some((currency) => !isSupportedTwoDecimalCurrency(currency))
    ) {
      throw new PaymentGatewayError("CONFIGURATION_INVALID");
    }
    this.certificateUrl = certificateUrl.toString();
  }

  async createIntent(request: PaymentIntentRequest): Promise<PaymentIntent> {
    assertPaymentRequest(request);
    assertGatewayCurrency(this.code, request.currency);
    if (!this.config.allowedCurrencies.has(request.currency)) throw new PaymentGatewayError("INVALID_CURRENCY");
    const invoiceDigest = await sha256Hex(`paypal:${request.organizationId}:${request.planVersionId}:${request.idempotencyKey}`);
    let response: unknown;
    try {
      response = await this.orderClient.createOrder({
        requestId: request.idempotencyKey,
        invoiceId: `matricia-${invoiceDigest.slice(0, 32)}`,
        amount: minorToDecimal(request.amountMinor),
        currency: request.currency,
        returnUrl: request.returnUrl,
      });
    } catch {
      throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    }
    const parsed = parseOrder(response);
    return {
      gateway: this.code,
      providerIntentId: parsed.id,
      status: "REQUIRES_CONFIRMATION",
      amountMinor: request.amountMinor,
      currency: request.currency,
      confirmation: { method: "GET", url: parsed.approvalUrl },
    };
  }

  async requestCapture(providerIntentId: string, idempotencyKey: string): Promise<{ status: "PENDING_WEBHOOK" }> {
    if (!/^[A-Z0-9-]{8,200}$/u.test(providerIntentId) || !/^[0-9a-f-]{36}$/iu.test(idempotencyKey)) {
      throw new PaymentGatewayError("INVALID_REQUEST");
    }
    let response: unknown;
    try {
      response = await this.orderClient.captureOrder({ orderId: providerIntentId, requestId: idempotencyKey });
    } catch {
      throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    }
    if (!isRecord(response) || response.id !== providerIntentId || !["COMPLETED", "APPROVED", "PAYER_ACTION_REQUIRED"].includes(String(response.status))) {
      throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    }
    return { status: "PENDING_WEBHOOK" };
  }

  async verifyWebhook(
    rawBody: Uint8Array,
    headers: Readonly<Record<string, string | undefined>>,
    receivedAt = new Date(),
  ): Promise<VerifiedPaymentEvent> {
    const transmissionId = header(headers, "paypal-transmission-id", 50);
    const transmissionTime = header(headers, "paypal-transmission-time", 100);
    const transmissionSignature = header(headers, "paypal-transmission-sig", 500);
    const certificateUrl = header(headers, "paypal-cert-url", 500);
    const algorithm = header(headers, "paypal-auth-algo", 100);
    const sentAt = Date.parse(transmissionTime);
    if (
      algorithm !== "SHA256withRSA" ||
      certificateUrl !== this.certificateUrl ||
      Number.isNaN(sentAt) ||
      Number.isNaN(receivedAt.getTime()) ||
      Math.abs(receivedAt.getTime() - sentAt) > 300_000
    ) {
      throw new PaymentGatewayError("INVALID_SIGNATURE");
    }
    const signedMessage = `${transmissionId}|${transmissionTime}|${this.config.webhookId}|${crc32(rawBody)}`;
    let verified = false;
    try {
      const verifier = createVerify("RSA-SHA256");
      verifier.update(signedMessage, "utf8");
      verifier.end();
      verified = verifier.verify(createPublicKey(this.config.certificatePem), transmissionSignature, "base64");
    } catch {
      throw new PaymentGatewayError("INVALID_SIGNATURE");
    }
    if (!verified) throw new PaymentGatewayError("INVALID_SIGNATURE");
    const event = parseCaptureEvent(rawBody);
    assertGatewayCurrency(this.code, event.currency);
    return {
      gateway: this.code,
      providerEventId: event.eventId,
      providerIntentId: event.orderId,
      eventType: "PAYMENT_SUCCEEDED",
      amountMinor: decimalToMinor(event.amount),
      currency: event.currency,
      paidAt: event.paidAt,
      paymentReference: event.captureId,
      payloadHash: await sha256Hex(rawBody),
      signatureFingerprint: await sha256Hex(transmissionSignature),
    };
  }
}

export class FetchPayPalOrderClient implements PayPalOrderClient {
  private readonly baseUrl: string;

  constructor(
    environment: "sandbox" | "live",
    private readonly clientId: string,
    private readonly clientSecret: string,
    private readonly timeoutMilliseconds = 10_000,
  ) {
    if (clientId.length < 8 || clientSecret.length < 8 || timeoutMilliseconds < 1_000 || timeoutMilliseconds > 30_000) {
      throw new PaymentGatewayError("CONFIGURATION_INVALID");
    }
    this.baseUrl = environment === "live" ? "https://api-m.paypal.com" : "https://api-m.sandbox.paypal.com";
  }

  async createOrder(input: { requestId: string; invoiceId: string; amount: string; currency: string; returnUrl: string }): Promise<unknown> {
    const tokenResponse = await fetch(`${this.baseUrl}/v1/oauth2/token`, {
      method: "POST",
      headers: {
        authorization: `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`, "utf8").toString("base64")}`,
        "content-type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials",
      signal: AbortSignal.timeout(this.timeoutMilliseconds),
      cache: "no-store",
    });
    if (!tokenResponse.ok) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    const tokenBody: unknown = await tokenResponse.json();
    const accessToken = isRecord(tokenBody) && typeof tokenBody.access_token === "string" ? tokenBody.access_token : null;
    if (!accessToken || accessToken.length > 4_096) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    const orderResponse = await fetch(`${this.baseUrl}/v2/checkout/orders`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
        "paypal-request-id": input.requestId,
        prefer: "return=representation",
      },
      body: JSON.stringify({
        intent: "CAPTURE",
        purchase_units: [{ invoice_id: input.invoiceId, amount: { currency_code: input.currency, value: input.amount } }],
        payment_source: { paypal: { experience_context: { return_url: input.returnUrl, cancel_url: input.returnUrl, user_action: "PAY_NOW" } } },
      }),
      signal: AbortSignal.timeout(this.timeoutMilliseconds),
      cache: "no-store",
    });
    if (!orderResponse.ok) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    return orderResponse.json();
  }

  async captureOrder(input: { orderId: string; requestId: string }): Promise<unknown> {
    const accessToken = await this.requestAccessToken();
    const response = await fetch(`${this.baseUrl}/v2/checkout/orders/${encodeURIComponent(input.orderId)}/capture`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
        "paypal-request-id": input.requestId,
        prefer: "return=representation",
      },
      body: "{}",
      signal: AbortSignal.timeout(this.timeoutMilliseconds),
      cache: "no-store",
    });
    if (!response.ok) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    return response.json();
  }

  private async requestAccessToken(): Promise<string> {
    const tokenResponse = await fetch(`${this.baseUrl}/v1/oauth2/token`, {
      method: "POST",
      headers: {
        authorization: `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`, "utf8").toString("base64")}`,
        "content-type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials",
      signal: AbortSignal.timeout(this.timeoutMilliseconds),
      cache: "no-store",
    });
    if (!tokenResponse.ok) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    const tokenBody: unknown = await tokenResponse.json();
    const accessToken = isRecord(tokenBody) && typeof tokenBody.access_token === "string" ? tokenBody.access_token : null;
    if (!accessToken || accessToken.length > 4_096) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
    return accessToken;
  }
}

function parseOrder(value: unknown): { id: string; approvalUrl: string } {
  if (!isRecord(value) || typeof value.id !== "string" || value.id.length < 8 || value.id.length > 200 || !Array.isArray(value.links)) {
    throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
  }
  const approval = value.links.find((link) => isRecord(link) && link.rel === "approve" && typeof link.href === "string");
  if (!isRecord(approval) || typeof approval.href !== "string") throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
  let url: URL;
  try {
    url = new URL(approval.href);
  } catch {
    throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
  }
  if (url.protocol !== "https:" || !isPayPalApprovalHost(url.hostname)) throw new PaymentGatewayError("PROVIDER_UNAVAILABLE");
  return { id: value.id, approvalUrl: url.toString() };
}

function parseCaptureEvent(rawBody: Uint8Array): { eventId: string; orderId: string; captureId: string; amount: string; currency: string; paidAt: string } {
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(rawBody));
  } catch {
    throw new PaymentGatewayError("INVALID_EVENT");
  }
  if (!isRecord(value) || value.event_type !== "PAYMENT.CAPTURE.COMPLETED" || typeof value.id !== "string" || !isRecord(value.resource)) {
    throw new PaymentGatewayError("UNSUPPORTED_EVENT");
  }
  const resource = value.resource;
  const amount = isRecord(resource.amount) ? resource.amount : null;
  const supplementary = isRecord(resource.supplementary_data) ? resource.supplementary_data : null;
  const relatedIds = supplementary && isRecord(supplementary.related_ids) ? supplementary.related_ids : null;
  const paidAt = typeof resource.create_time === "string" ? resource.create_time : value.create_time;
  if (
    value.id.length < 8 || value.id.length > 200 ||
    resource.status !== "COMPLETED" || typeof resource.id !== "string" || resource.id.length < 8 || resource.id.length > 200 ||
    !amount || typeof amount.value !== "string" || typeof amount.currency_code !== "string" || !/^[A-Z]{3}$/u.test(amount.currency_code) ||
    !relatedIds || typeof relatedIds.order_id !== "string" || relatedIds.order_id.length < 8 || relatedIds.order_id.length > 200 ||
    typeof paidAt !== "string" || Number.isNaN(Date.parse(paidAt))
  ) {
    throw new PaymentGatewayError("INVALID_EVENT");
  }
  return { eventId: value.id, orderId: relatedIds.order_id, captureId: resource.id, amount: amount.value, currency: amount.currency_code, paidAt };
}

function header(headers: Readonly<Record<string, string | undefined>>, name: string, maximum: number): string {
  const value = headers[name];
  if (!value || value.length > maximum) throw new PaymentGatewayError("INVALID_SIGNATURE");
  return value;
}

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function isPayPalApiHost(hostname: string): boolean {
  return hostname === "api-m.paypal.com" || hostname === "api-m.sandbox.paypal.com";
}

function isPayPalApprovalHost(hostname: string): boolean {
  return hostname === "paypal.com" || hostname.endsWith(".paypal.com");
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
