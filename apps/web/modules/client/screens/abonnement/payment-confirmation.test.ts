import { describe, expect, it } from "vitest";
import { parsePayPalCaptureReturn, parsePaymentIntent } from "./payment-confirmation";

const intent = {
  paymentIntentId: "11111111-1111-4111-8111-111111111111",
  providerIntentId: "ORDER-12345678",
  gateway: "PAYPAL",
  status: "REQUIRES_CONFIRMATION",
  confirmation: { method: "GET", url: "https://www.sandbox.paypal.com/checkoutnow?token=ORDER-12345678" },
};

describe("payment confirmation UI contract", () => {
  it("accepts a safe PayPal approval and binds the return token to stored order", () => {
    expect(parsePaymentIntent(intent)).not.toBeNull();
    expect(parsePayPalCaptureReturn("?payment=pending&token=ORDER-12345678&PayerID=PAYER-1", JSON.stringify(intent)))
      .toEqual({ paymentIntentId: intent.paymentIntentId });
  });

  it("rejects tampered return tokens and unsafe confirmation URLs", () => {
    expect(parsePayPalCaptureReturn("?payment=pending&token=OTHER&PayerID=PAYER-1", JSON.stringify(intent))).toBeNull();
    expect(parsePaymentIntent({ ...intent, confirmation: { method: "GET", url: "javascript:alert(1)" } })).toBeNull();
  });

  it("accepts only bounded string fields for CMI POST", () => {
    expect(parsePaymentIntent({ ...intent, gateway: "CMI", providerIntentId: "matricia-order", confirmation: { method: "POST", url: "https://testpayment.cmi.co.ma/gate", fields: { oid: "matricia-order", hash: "signed" } } })).not.toBeNull();
    expect(parsePaymentIntent({ ...intent, gateway: "CMI", confirmation: { method: "POST", url: "https://testpayment.cmi.co.ma/gate", fields: { "bad name": "value" } } })).toBeNull();
  });
});
