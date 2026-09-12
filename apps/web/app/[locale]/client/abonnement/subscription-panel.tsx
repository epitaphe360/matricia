"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { formatMinor, type SubscriptionDashboard } from "@/lib/subscriptions/model";
import { changePlanAction, ensureTrialAction, type SubscriptionActionState } from "./actions";
import type { getSubscriptionMessages } from "./messages";

const idle: SubscriptionActionState = { status: "idle" };

export function SubscriptionPanel({
  dashboard,
  locale,
  messages,
  keys,
}: {
  dashboard: SubscriptionDashboard;
  locale: "fr" | "ar";
  messages: ReturnType<typeof getSubscriptionMessages>;
  keys: Record<string, string>;
}) {
  const [trial, trialAction, trialPending] = useActionState(ensureTrialAction, idle);
  const [change, changeAction, changePending] = useActionState(changePlanAction, idle);
  const subscription = dashboard.subscription;
  return <div className="space-y-6">
    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-current">
      <h2 id="subscription-current" className="text-xl font-semibold">{messages.current}</h2>
      {subscription ? <dl className="mt-4 grid gap-3 sm:grid-cols-2">
        <div><dt className="text-sm text-muted-foreground">Status</dt><dd className="font-medium">{subscription.status}</dd></div>
        <div><dt className="text-sm text-muted-foreground">Interval</dt><dd>{subscription.billingInterval ?? "—"}</dd></div>
        <div><dt className="text-sm text-muted-foreground">Expiration</dt><dd dir="ltr">{subscription.currentPeriodEnd ?? "—"}</dd></div>
      </dl> : <form action={trialAction} className="mt-4 space-y-3">
        <p className="text-sm text-muted-foreground">{messages.noSubscription}</p>
        <Hidden locale={locale} dashboard={dashboard} idempotencyKey={keys.trial} />
        <Button disabled={trialPending} className="min-h-11">{trialPending ? messages.pending : messages.trial}</Button>
        <Feedback state={trial} messages={messages} />
      </form>}
    </section>
    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-plans">
      <h2 id="subscription-plans" className="text-xl font-semibold">{messages.plans}</h2>
      <ul className="mt-4 grid gap-4 md:grid-cols-3">{dashboard.plans.map((plan) => <li key={plan.id} className="rounded-xl border p-4">
        <h3 className="text-lg font-semibold">{plan.code} · v{plan.version}</h3>
        <p className="mt-2">{formatMinor(plan.monthlyPriceMinor, plan.currency, locale)} {messages.monthly}</p>
        <p>{formatMinor(plan.annualPriceMinor, plan.currency, locale)} {messages.annual}</p>
        {subscription && subscription.planVersionId !== plan.id ? <form action={changeAction} className="mt-4 space-y-3">
          <Hidden locale={locale} dashboard={dashboard} idempotencyKey={keys[plan.id] ?? keys.trial} />
          <input type="hidden" name="subscriptionId" value={subscription.id} />
          <input type="hidden" name="targetPlanVersionId" value={plan.id} />
          <label className="block text-sm font-medium" htmlFor={`mode-${plan.id}`}>{messages.change}</label>
          <select id={`mode-${plan.id}`} name="changeMode" className="min-h-11 w-full rounded-md border bg-background px-3">
            <option value="UPGRADE_IMMEDIATE">{messages.immediate}</option>
            <option value="DOWNGRADE_NEXT_CYCLE">{messages.nextCycle}</option>
          </select>
          <Button disabled={changePending} className="min-h-11 w-full">{changePending ? messages.pending : messages.change}</Button>
          <Feedback state={change} messages={messages} />
        </form> : null}
      </li>)}</ul>
    </section>
    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-cycles">
      <h2 id="subscription-cycles" className="text-xl font-semibold">{messages.cycles}</h2>
      {subscription?.cycles.length ? <ul className="mt-4 space-y-2">{subscription.cycles.map((cycle) => <li key={cycle.id} className="flex flex-wrap justify-between gap-2 rounded-lg border p-3">
        <span>#{cycle.cycleNumber}</span><span>{formatMinor(cycle.amountMinor, cycle.currency, locale)}</span><time dateTime={cycle.periodEnd} dir="ltr">{cycle.periodEnd}</time>
      </li>)}</ul> : <p className="mt-4 text-sm text-muted-foreground">{messages.emptyCycles}</p>}
    </section>
  </div>;
}

function Hidden({ locale, dashboard, idempotencyKey }: { locale: string; dashboard: SubscriptionDashboard; idempotencyKey: string }) {
  return <><input type="hidden" name="locale" value={locale} /><input type="hidden" name="organizationId" value={dashboard.organizationId} /><input type="hidden" name="idempotencyKey" value={idempotencyKey} /></>;
}

function Feedback({ state, messages }: { state: SubscriptionActionState; messages: ReturnType<typeof getSubscriptionMessages> }) {
  return state.status === "error" ? <p role="alert" className="text-sm text-destructive">{messages.error}</p> : state.status === "success" ? <p role="status" className="text-sm text-primary">{messages.saved}</p> : null;
}
