"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Label } from "@/modules/shared/ui/label";
import { Textarea } from "@/modules/shared/ui/textarea";
import { formatMinor, type BillingDashboard } from "@/modules/provider/data/billing/model";
import { requestPaymentPlan, type BillingActionState } from "@/modules/provider/screens/facturation/actions";
import type { BillingMessages } from "@/modules/provider/screens/facturation/messages";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const idle: BillingActionState = { status: "idle" };
const control = "min-h-11 w-full rounded-md border bg-background px-3 text-base";

export function SchedulePlanForm({
  dashboard,
  locale,
  m,
  keyValue,
}: {
  dashboard: BillingDashboard;
  locale: Locale;
  m: BillingMessages;
  keyValue: string;
}) {
  const prefix = useId();
  const [state, action, pending] = useActionState(requestPaymentPlan, idle);
  const open = dashboard.invoices.filter((row) => row.outstandingMinor !== "0");
  const feedback = state.status === "success" ? m.success : state.status === "error" ? (state.reason === "VALIDATION" ? m.validation : state.reason === "FORBIDDEN" ? m.forbidden : state.reason === "CONFLICT" ? m.conflict : m.failed) : "";
  return (
    <form action={action} className="client-stack rounded-xl border p-4">
      <input type="hidden" name="organizationId" value={dashboard.organizationId} />
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={keyValue} />
      <input type="hidden" name="currency" value="MAD" />
      <h3>{m.requestPlan}</h3>
      <p className="text-sm text-muted-foreground">{m.planHint}</p>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-2 sm:col-span-2">
          <Label htmlFor={`${prefix}-invoice`}>{m.invoice}</Label>
          <select id={`${prefix}-invoice`} name="invoiceId" required className={control} defaultValue="">
            <option value="" disabled>—</option>
            {open.map((row) => (
              <option key={row.id} value={row.id}>{row.number} · {formatMinor(row.outstandingMinor, row.currency, locale)}</option>
            ))}
          </select>
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-due1`}>{m.firstDue}</Label>
          <Input id={`${prefix}-due1`} name="dueOn1" type="date" required className={control} />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-amount1`}>{m.firstAmount}</Label>
          <Input id={`${prefix}-amount1`} name="amount1" inputMode="decimal" dir="ltr" placeholder="625,25" required className={control} />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-due2`}>{m.secondDue}</Label>
          <Input id={`${prefix}-due2`} name="dueOn2" type="date" required className={control} />
        </div>
        <div className="space-y-2">
          <Label htmlFor={`${prefix}-amount2`}>{m.secondAmount}</Label>
          <Input id={`${prefix}-amount2`} name="amount2" inputMode="decimal" dir="ltr" placeholder="625,25" required className={control} />
        </div>
        <div className="space-y-2 sm:col-span-2">
          <Label htmlFor={`${prefix}-reason`}>{m.planReason}</Label>
          <Textarea id={`${prefix}-reason`} name="reason" required minLength={10} maxLength={2000} />
        </div>
      </div>
      <Button disabled={pending || open.length === 0} className="min-h-11">{pending ? m.pending : m.requestPlan}</Button>
      <p role={state.status === "error" ? "alert" : "status"} aria-live="polite" className={state.status === "error" ? "text-sm text-destructive" : "text-sm text-primary"}>{feedback}</p>
    </form>
  );
}
