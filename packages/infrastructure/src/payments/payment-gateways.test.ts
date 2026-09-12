import { createHash, generateKeyPairSync, sign } from "node:crypto";
import { describe, expect, it, vi } from "vitest";
import { CmiPaymentGateway } from "./cmi-gateway";
import { PaymentGatewayError, type PaymentIntentRequest } from "./contracts";
import { createPaymentGateway } from "./gateway-factory";
import { PayPalPaymentGateway } from "./paypal-gateway";

const request: PaymentIntentRequest = {
  organizationId: "11111111-1111-4111-8111-111111111111",
  planVersionId: "22222222-2222-4222-8222-222222222222",
  billingInterval: "MONTHLY",
  amountMinor: "12345",
  currency: "MAD",
  idempotencyKey: "33333333-3333-4333-8333-333333333333",
  returnUrl: "https://app.matricia.test/fr/client/abonnement?payment=pending",
};

describe("CmiPaymentGateway", () => {
  const gateway = new CmiPaymentGateway({
    gatewayUrl: "https://testpayment.cmi.co.ma/fim/est3Dgate",
    allowedGatewayHosts: new Set(["testpayment.cmi.co.ma"]),
    merchantId: "merchant-test",
    storeKey: "store-key-long-enough",
  });

  it("produit une requête signée déterministe sans exposer la clé", async () => {
    const first = await gateway.createIntent(request);
    const second = await gateway.createIntent(request);
    expect(first.providerIntentId).toBe(second.providerIntentId);
    expect(first.confirmation?.method).toBe("POST");
    expect(JSON.stringify(first)).not.toContain("store-key-long-enough");
  });

  it("accepte un callback signé et rejette sa modification", async () => {
    const intent = await gateway.createIntent(request);
    const values: Record<string, string> = {
      oid: intent.providerIntentId,
      TransId: "transaction-12345",
      amount: "123.45",
      currency: "504",
      Response: "Approved",
      ProcReturnCode: "00",
      mdStatus: "1",
      AuthCode: "auth-12345",
    };
    const names = Object.keys(values);
    const hashParamsValue = names.map((name) => values[name]).join("");
    const hash = createHash("sha1").update(`${hashParamsValue}store-key-long-enough`, "utf8").digest("base64");
    const body = new URLSearchParams({ ...values, HASHPARAMS: `${names.join(":")}:`, HASHPARAMSVAL: hashParamsValue, HASH: hash });
    const raw = new TextEncoder().encode(body.toString());
    const event = await gateway.verifyWebhook(raw, {}, new Date("2026-09-12T12:00:00Z"));
    expect(event).toMatchObject({ gateway: "CMI", amountMinor: "12345", currency: "MAD", providerEventId: "transaction-12345" });
    body.set("amount", "999.99");
    await expect(gateway.verifyWebhook(new TextEncoder().encode(body.toString()), {})).rejects.toMatchObject({ code: "INVALID_SIGNATURE" });
  });
});

describe("PayPalPaymentGateway", () => {
  const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const certificatePem = publicKey.export({ type: "spki", format: "pem" }).toString();
  const certificateUrl = "https://api-m.sandbox.paypal.com/v1/notifications/certs/CERT-test";
  const client = {
    createOrder: vi.fn(async () => ({ id: "ORDER-12345678", links: [{ rel: "approve", href: "https://www.sandbox.paypal.com/checkoutnow?token=ORDER-12345678" }] })),
    captureOrder: vi.fn(async () => ({ id: "ORDER-12345678", status: "COMPLETED" })),
  };
  const gateway = new PayPalPaymentGateway(client, { webhookId: "WEBHOOK123", certificateUrl, certificatePem, allowedCurrencies: new Set(["EUR"]) });

  it("transmet montant exact et clé d’idempotence au port Orders", async () => {
    const intent = await gateway.createIntent({ ...request, currency: "EUR" });
    expect(intent.providerIntentId).toBe("ORDER-12345678");
    expect(client.createOrder).toHaveBeenCalledWith(expect.objectContaining({ amount: "123.45", requestId: request.idempotencyKey }));
  });

  it("capture avec une clé stable sans activer avant le webhook", async () => {
    const result = await gateway.requestCapture("ORDER-12345678", request.idempotencyKey);
    expect(result).toEqual({ status: "PENDING_WEBHOOK" });
    expect(client.captureOrder).toHaveBeenCalledWith({ orderId: "ORDER-12345678", requestId: request.idempotencyKey });
  });

  it("vérifie RSA sur le raw body, rejette altération et événement périmé", async () => {
    const receivedAt = new Date("2026-09-12T12:00:00Z");
    const body = new TextEncoder().encode(JSON.stringify({
      id: "EVENT-12345678", event_type: "PAYMENT.CAPTURE.COMPLETED", create_time: receivedAt.toISOString(),
      resource: { id: "CAPTURE-12345678", status: "COMPLETED", create_time: receivedAt.toISOString(), amount: { value: "123.45", currency_code: "EUR" }, supplementary_data: { related_ids: { order_id: "ORDER-12345678" } } },
    }));
    const transmissionId = "transmission-123";
    const transmissionTime = receivedAt.toISOString();
    const signature = sign("RSA-SHA256", Buffer.from(`${transmissionId}|${transmissionTime}|WEBHOOK123|${crc32(body)}`), privateKey).toString("base64");
    const headers = { "paypal-auth-algo": "SHA256withRSA", "paypal-cert-url": certificateUrl, "paypal-transmission-id": transmissionId, "paypal-transmission-sig": signature, "paypal-transmission-time": transmissionTime };
    const first = await gateway.verifyWebhook(body, headers, receivedAt);
    const replay = await gateway.verifyWebhook(body, headers, receivedAt);
    expect(replay).toEqual(first);
    const altered = new Uint8Array(body);
    const alteredIndex = altered.length - 2;
    altered[alteredIndex] = (altered[alteredIndex] ?? 0) ^ 1;
    await expect(gateway.verifyWebhook(altered, headers, receivedAt)).rejects.toMatchObject({ code: "INVALID_SIGNATURE" });
    await expect(gateway.verifyWebhook(body, headers, new Date(receivedAt.getTime() + 300_001))).rejects.toMatchObject({ code: "INVALID_SIGNATURE" });
  });
});

it("refuse un provider absent de l'allowlist et un mode live non autorisé", () => {
  expect(() => createPaymentGateway({ provider: "CMI", allowedProviders: new Set(["DEMO"]), liveEnabled: false })).toThrow(PaymentGatewayError);
});

it("refuse une devise à exposant non supporté", async () => {
  const gateway = new CmiPaymentGateway({ gatewayUrl: "https://testpayment.cmi.co.ma/fim/est3Dgate", allowedGatewayHosts: new Set(["testpayment.cmi.co.ma"]), merchantId: "merchant-test", storeKey: "store-key-long-enough" });
  await expect(gateway.createIntent({ ...request, currency: "JPY" })).rejects.toMatchObject({ code: "INVALID_CURRENCY" });
});

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
