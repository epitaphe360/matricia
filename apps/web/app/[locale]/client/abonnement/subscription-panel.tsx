"use client";

import { useActionState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { formatMinor, planChangeMode, type SubscriptionDashboard } from "@/lib/subscriptions/model";
import { changePlanAction, ensureTrialAction, type SubscriptionActionState } from "./actions";
import type { SubscriptionMessages } from "./messages";
import { PaymentIntentButton } from "./payment-intent-button";

const idle: SubscriptionActionState = { status: "idle" };

export function SubscriptionPanel({ dashboard, locale, messages, keys }: { dashboard: SubscriptionDashboard; locale: "fr" | "ar"; messages: SubscriptionMessages; keys: Record<string, string> }) {
  const [trialState, trialAction, trialPending] = useActionState(ensureTrialAction, idle);
  const [changeState, changeAction, changePending] = useActionState(changePlanAction, idle);
  const subscription = dashboard.subscription;
  const currentPlan = subscription?.currentPlan ?? null;
  const pendingPlan = subscription?.pendingPlan ?? null;

  return <div className="space-y-6">
    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-current">
      <h2 id="subscription-current" className="text-xl font-semibold">{messages.current}</h2>
      {subscription ? <><dl className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"><Metric label={messages.status} value={subscription.status}/><Metric label={messages.interval} value={subscription.billingInterval??"—"}/><Metric label={messages.expires} value={subscription.currentPeriodEnd??"—"}/><Metric label={messages.planVersion} value={currentPlan?`${currentPlan.code} · v${currentPlan.version}`:subscription.planVersionId?.slice(0,8)??"—"}/>{subscription.pendingPlanVersionId?<Metric label={messages.pendingPlan} value={pendingPlan?`${pendingPlan.code} · v${pendingPlan.version}`:subscription.pendingPlanVersionId.slice(0,8)}/>:null}{subscription.pendingChangeEffectiveAt?<Metric label={messages.effectiveAt} value={subscription.pendingChangeEffectiveAt}/>:null}</dl>{subscription.status!=="ACTIVE"?<p className="mt-4 rounded-lg bg-muted p-3 text-sm text-muted-foreground">{messages.selectPaidPlan}</p>:null}</> : dashboard.capabilities.canStartTrial ? <form action={trialAction} className="mt-4 space-y-3"><p className="text-sm text-muted-foreground">{messages.noSubscription}</p><p className="text-sm">{messages.trialRule}</p><Hidden locale={locale} dashboard={dashboard} idempotencyKey={keys.trial}/><Button disabled={trialPending} className="min-h-11 w-full sm:w-auto">{trialPending?messages.pending:messages.trial}</Button><Feedback state={trialState} messages={messages}/></form> : <div className="mt-4 space-y-2"><p className="text-sm text-muted-foreground">{messages.noSubscription}</p><p className="text-sm">{messages.noPermission}</p></div>}
    </section>

    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-plans">
      <h2 id="subscription-plans" className="text-xl font-semibold">{messages.plans}</h2>
      <ul className="mt-4 grid gap-4 md:grid-cols-3">{dashboard.plans.map((plan) => { const mode=currentPlan?planChangeMode(currentPlan.monthlyPriceMinor,plan.monthlyPriceMinor):null; const canChange=dashboard.capabilities.canChangePlan&&subscription?.status==="ACTIVE"&&subscription.planVersionId!==plan.id&&mode!==null;const canActivate=dashboard.capabilities.canChangePlan&&subscription!==null&&subscription.status!=="ACTIVE"; return <li key={plan.id} className={plan.code==="GOLD"?"rounded-xl border-2 border-primary p-4":"rounded-xl border p-4"}><div className="flex flex-wrap items-center justify-between gap-2"><h3 className="text-lg font-semibold">{plan.code} · v{plan.version}</h3>{plan.code==="GOLD"?<Badge>{messages.recommended}</Badge>:null}</div><p className="mt-3 text-lg font-medium">{formatMinor(plan.monthlyPriceMinor,plan.currency,locale)} <span className="text-sm font-normal text-muted-foreground">{messages.monthly}</span></p><p>{formatMinor(plan.annualPriceMinor,plan.currency,locale)} <span className="text-sm text-muted-foreground">{messages.annual}</span></p><dl className="mt-3 space-y-2 text-sm"><Metric label={messages.credits} value={plan.monthlyCreditGrant}/><Metric label={messages.validFrom} value={plan.validFrom}/>{plan.validTo?<Metric label={messages.validTo} value={plan.validTo}/>:null}</dl>{canActivate?<div className="mt-4 space-y-2"><PaymentIntentButton locale={locale} organizationId={dashboard.organizationId} planVersionId={plan.id} billingInterval="MONTHLY" messages={messages}/><PaymentIntentButton locale={locale} organizationId={dashboard.organizationId} planVersionId={plan.id} billingInterval="ANNUAL" messages={messages}/></div>:null}{canChange?<form action={changeAction} className="mt-4 space-y-3"><Hidden locale={locale} dashboard={dashboard} idempotencyKey={keys[plan.id]??keys.trial}/><input type="hidden" name="subscriptionId" value={subscription.id}/><input type="hidden" name="targetPlanVersionId" value={plan.id}/><input type="hidden" name="changeMode" value={mode}/><p className="text-sm text-muted-foreground">{mode==="UPGRADE_IMMEDIATE"?messages.immediate:messages.nextCycle}</p><Button disabled={changePending} className="min-h-11 w-full">{changePending?messages.pending:messages.change}</Button><Feedback state={changeState} messages={messages}/></form>:null}</li>})}</ul>
      {!dashboard.capabilities.canChangePlan&&subscription?<p className="mt-4 text-sm text-muted-foreground">{messages.noPermission}</p>:null}
    </section>

    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-cycles"><h2 id="subscription-cycles" className="text-xl font-semibold">{messages.cycles}</h2>{subscription?.cycles.length?<ul className="mt-4 space-y-2">{subscription.cycles.map((cycle)=><li key={cycle.id} className="grid gap-1 rounded-lg border p-3 sm:grid-cols-4"><span dir="ltr">#{cycle.cycleNumber}</span><span>{messages.cyclePlan}: <strong dir="ltr">{cycle.plan.code} · v{cycle.plan.version}</strong></span><span dir="ltr">{formatMinor(cycle.amountMinor,cycle.currency,locale)}</span><time dateTime={cycle.periodEnd} dir="ltr">{cycle.periodEnd}</time></li>)}</ul>:<p className="mt-4 text-sm text-muted-foreground">{messages.emptyCycles}</p>}</section>

    <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6" aria-labelledby="subscription-history"><h2 id="subscription-history" className="text-xl font-semibold">{messages.history}</h2>{subscription?.transitions.length?<ol className="mt-4 space-y-2">{subscription.transitions.map((event)=><li key={event.id} className="rounded-lg border p-3"><div className="flex flex-wrap items-center gap-2"><span dir="ltr">{event.fromStatus??"∅"}</span><span aria-hidden="true">→</span><strong dir="ltr">{event.toStatus}</strong></div><p className="mt-1 text-sm text-muted-foreground"><span dir="ltr">{event.reasonCode}</span> · <time dateTime={event.occurredAt} dir="ltr">{event.occurredAt}</time></p></li>)}</ol>:<p className="mt-4 text-sm text-muted-foreground">{messages.emptyHistory}</p>}</section>
  </div>;
}

function Hidden({locale,dashboard,idempotencyKey}:{locale:string;dashboard:SubscriptionDashboard;idempotencyKey:string}){return <><input type="hidden" name="locale" value={locale}/><input type="hidden" name="organizationId" value={dashboard.organizationId}/><input type="hidden" name="idempotencyKey" value={idempotencyKey}/></>}
function Feedback({state,messages}:{state:SubscriptionActionState;messages:SubscriptionMessages}){return state.status==="error"?<p role="alert" className="text-sm text-destructive">{messages.error}</p>:state.status==="success"?<p role="status" className="text-sm text-primary">{messages.saved}</p>:null}
function Metric({label,value}:{label:string;value:string}){return <div><dt className="text-sm text-muted-foreground">{label}</dt><dd className="font-medium" dir="auto">{value}</dd></div>}
