"use client";

import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import type { SubscriptionMessages } from "./messages";
import { parsePayPalCaptureReturn, parsePaymentIntent, paypalCaptureStorageKey, type PaymentIntentResponse } from "./payment-confirmation";

type Props = { locale: "fr" | "ar"; organizationId: string; planVersionId: string; billingInterval: "MONTHLY" | "ANNUAL"; messages: SubscriptionMessages };
let paypalCaptureClaimed = false;

export function PaymentIntentButton({ locale, organizationId, planVersionId, billingInterval, messages }: Props) {
  const key = useRef<string>(crypto.randomUUID());
  const captureStarted = useRef(false);
  const [state, setState] = useState<"idle" | "pending" | "success" | "error">("idle");

  useEffect(() => {
    if (captureStarted.current || paypalCaptureClaimed) return;
    const capture = parsePayPalCaptureReturn(window.location.search, sessionStorage.getItem(paypalCaptureStorageKey));
    if (!capture) return;
    paypalCaptureClaimed = true;
    captureStarted.current = true;
    queueMicrotask(() => setState("pending"));
    void fetch("/api/payments/paypal/capture", {
      method: "POST",
      credentials: "same-origin",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(capture),
    }).then((response) => {
      if (!response.ok) throw new Error("capture rejected");
      sessionStorage.removeItem(paypalCaptureStorageKey);
      const clean = new URL(window.location.href);
      clean.searchParams.delete("token"); clean.searchParams.delete("PayerID"); clean.searchParams.delete("payment");
      window.history.replaceState({}, "", `${clean.pathname}${clean.search}${clean.hash}`);
      setState("success");
    }).catch(() => { paypalCaptureClaimed = false; setState("error"); });
  }, []);

  async function create() {
    setState("pending");
    try {
      const response = await fetch("/api/payments/intents", {
        method: "POST", credentials: "same-origin", headers: { "content-type": "application/json" },
        body: JSON.stringify({ locale, organizationId, planVersionId, billingInterval, idempotencyKey: key.current }),
      });
      if (!response.ok) throw new Error("intent rejected");
      const intent = parsePaymentIntent(await response.json());
      if (!intent) throw new Error("invalid intent");
      confirmPayment(intent);
    } catch {
      setState("error");
    }
  }

  function confirmPayment(intent: PaymentIntentResponse) {
    if (intent.gateway === "PAYPAL" && intent.confirmation?.method === "GET") {
      sessionStorage.setItem(paypalCaptureStorageKey, JSON.stringify({ paymentIntentId: intent.paymentIntentId, providerIntentId: intent.providerIntentId }));
      window.location.assign(intent.confirmation.url);
      return;
    }
    if (intent.gateway === "CMI" && intent.confirmation?.method === "POST") {
      const form = document.createElement("form");
      form.method = "POST"; form.action = intent.confirmation.url; form.hidden = true;
      for (const [name, value] of Object.entries(intent.confirmation.fields)) {
        const input = document.createElement("input"); input.type = "hidden"; input.name = name; input.value = value; form.append(input);
      }
      document.body.append(form); form.submit(); return;
    }
    setState("success");
  }

  return <div className="space-y-2"><Button type="button" variant={billingInterval === "ANNUAL" ? "default" : "outline"} className="min-h-11 w-full" disabled={state === "pending" || state === "success"} onClick={create}>{state === "pending" ? messages.pending : billingInterval === "MONTHLY" ? messages.paymentMonthly : messages.paymentAnnual}</Button>{state === "success" ? <p role="status" className="text-sm text-primary">{messages.paymentCreated}</p> : state === "error" ? <p role="alert" className="text-sm text-destructive">{messages.paymentError}</p> : null}</div>;
}
