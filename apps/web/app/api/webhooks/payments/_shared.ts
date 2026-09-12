import { randomUUID } from "node:crypto";
import { PaymentGatewayError, type PaymentWebhookVerifier } from "@matricia/infrastructure";
import { NextResponse } from "next/server";
import { getSupabaseAdminClient } from "@/lib/supabase/admin";

const maximumBodyBytes = 1_048_576;

export async function processPaymentWebhook(
  request: Request,
  verifier: PaymentWebhookVerifier,
  headers: Readonly<Record<string, string | undefined>>,
  expectedMediaType: string,
) {
  const declaredHeader = request.headers.get("content-length");
  if (declaredHeader !== null) {
    const declared = Number(declaredHeader);
    if (!Number.isSafeInteger(declared) || declared < 0 || declared > maximumBodyBytes) {
      return NextResponse.json({ error: "PAYLOAD_TOO_LARGE" }, { status: 413 });
    }
  }
  const mediaType = request.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase();
  if (mediaType !== expectedMediaType) return NextResponse.json({ error: "INVALID_PAYLOAD" }, { status: 415 });
  const rawBody = new Uint8Array(await request.arrayBuffer());
  if (rawBody.byteLength === 0 || rawBody.byteLength > maximumBodyBytes) {
    return NextResponse.json({ error: "INVALID_PAYLOAD" }, { status: rawBody.byteLength > maximumBodyBytes ? 413 : 400 });
  }
  let event;
  try {
    event = await verifier.verifyWebhook(rawBody, headers);
  } catch (error) {
    const invalidSignature = error instanceof PaymentGatewayError && error.code === "INVALID_SIGNATURE";
    return NextResponse.json({ error: invalidSignature ? "INVALID_SIGNATURE" : "INVALID_EVENT" }, { status: invalidSignature ? 401 : 400 });
  }
  const { data, error } = await getSupabaseAdminClient().rpc("process_verified_subscription_payment", {
    p_gateway: event.gateway,
    p_provider_event_id: event.providerEventId,
    p_provider_intent_id: event.providerIntentId,
    p_event_type: event.eventType,
    p_amount_minor: event.amountMinor,
    p_currency: event.currency,
    p_paid_at: event.paidAt,
    p_payment_reference: event.paymentReference,
    p_payload_hash: event.payloadHash,
    p_signature_fingerprint: event.signatureFingerprint,
    p_correlation_id: randomUUID(),
  });
  if (error) return NextResponse.json({ error: "PAYMENT_EVENT_REJECTED" }, { status: 409 });
  return NextResponse.json({ received: true, replayed: isRecord(data) && data.replayed === true });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
