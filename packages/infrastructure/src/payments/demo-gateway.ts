import { assertPaymentRequest, type PaymentGateway, type PaymentIntent, type PaymentIntentRequest, type VerifiedPaymentEvent } from "./contracts.js";
import { sha256Hex, signWebhook, verifyPaymentWebhook } from "./webhook.js";

export class DemoPaymentGateway implements PaymentGateway {
  readonly code = "DEMO" as const;

  async createIntent(request: PaymentIntentRequest): Promise<PaymentIntent> {
    assertPaymentRequest(request);
    const digest=await sha256Hex(`demo-intent:${request.idempotencyKey}:${request.organizationId}:${request.planVersionId}:${request.billingInterval}:${request.amountMinor}:${request.currency}`);
    return { gateway:this.code, providerIntentId:`demo_pi_${digest.slice(0,32)}`, status:"REQUIRES_CONFIRMATION", amountMinor:request.amountMinor, currency:request.currency, confirmationUrl:null };
  }

  verifyWebhook(rawBody: Uint8Array, signatureHeader: string, secret: string): Promise<VerifiedPaymentEvent> {
    return verifyPaymentWebhook(rawBody,signatureHeader,secret,this.code);
  }

  async simulateSucceededWebhook(input:{providerIntentId:string;amountMinor:string;currency:string;paidAt:string;paymentReference:string},secret:string){
    const eventDigest=await sha256Hex(`demo-event:${input.providerIntentId}:${input.paymentReference}`);
    const rawBody=new TextEncoder().encode(JSON.stringify({gateway:this.code,providerEventId:`demo_evt_${eventDigest.slice(0,32)}`,providerIntentId:input.providerIntentId,eventType:"PAYMENT_SUCCEEDED",amountMinor:input.amountMinor,currency:input.currency,paidAt:input.paidAt,paymentReference:input.paymentReference}));
    return {rawBody,signatureHeader:await signWebhook(rawBody,secret)};
  }
}
