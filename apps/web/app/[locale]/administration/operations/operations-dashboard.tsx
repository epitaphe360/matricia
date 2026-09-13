import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import type { AdminOperationsDashboard, SafeAuditEvent } from "@/lib/admin-operations/model";
import type { AdminOperationsMessages } from "./messages";

function signalLabel(signal: SafeAuditEvent["signal"], m: AdminOperationsMessages) {
  return signal === "NOTIFICATION" ? m.notification : signal === "DEAD_LETTER" ? m.deadLetter : signal === "OUTBOX" ? m.outboxSignal : m.general;
}
function metric(label: string, value: number) { return <Card><CardHeader className="pb-2"><CardDescription>{label}</CardDescription><CardTitle className="text-3xl" dir="ltr">{value}</CardTitle></CardHeader></Card>; }

export function OperationsDashboard({ dashboard, locale, messages: m }: { dashboard: AdminOperationsDashboard; locale: "fr" | "ar"; messages: AdminOperationsMessages }) {
  const formatter = new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short" });
  return <div className="space-y-8">
    <Alert><AlertTitle>{m.safetyTitle}</AlertTitle><AlertDescription>{m.safetyText}</AlertDescription></Alert>
    <section aria-labelledby="operations-summary"><div className="mb-4 flex flex-wrap items-center justify-between gap-3"><h2 id="operations-summary" className="text-2xl font-semibold">{m.audit}</h2><Badge variant="outline">{m.readOnly}</Badge></div><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
      {metric(m.auditedEvents, dashboard.summary.auditedEvents)}{metric(m.systemEvents, dashboard.summary.systemEvents)}{metric(m.notificationSignals, dashboard.summary.notificationSignals)}{metric(m.deadLetterSignals, dashboard.summary.deadLetterSignals)}{metric(m.outboxSignals, dashboard.summary.outboxSignals)}
    </div></section>
    <section aria-labelledby="restricted-projections" className="grid gap-4 lg:grid-cols-2"><h2 id="restricted-projections" className="sr-only">{m.safetyTitle}</h2>{[
      { title: m.outbox, capability: dashboard.capabilities.outbox }, { title: m.deliveries, capability: dashboard.capabilities.notificationDeliveries },
    ].map(({ title, capability }) => <Card key={title}><CardHeader><CardTitle>{title}</CardTitle><CardDescription>{capability.available ? m.readOnly : m.projectionUnavailable}</CardDescription></CardHeader><CardContent><p className="leading-7 text-muted-foreground">{m.projectionText}</p></CardContent></Card>)}</section>
    <section aria-labelledby="latest-audit-events"><h2 id="latest-audit-events" className="mb-4 text-2xl font-semibold">{m.latestEvents}</h2>{dashboard.events.length === 0 ? <p className="rounded-xl border bg-card p-5 text-muted-foreground">{m.noEvents}</p> : <div className="space-y-3">{dashboard.events.map((event) => <Card key={event.id}><CardContent className="grid min-w-0 gap-3 p-4 md:grid-cols-[minmax(0,1.2fr)_minmax(0,.8fr)]"><div className="min-w-0"><div className="flex flex-wrap items-center gap-2"><Badge variant={event.signal === "DEAD_LETTER" ? "destructive" : "outline"}>{signalLabel(event.signal, m)}</Badge><strong className="break-words">{event.action}</strong></div><p className="mt-2 text-sm text-muted-foreground">{m.resource}: <span dir="ltr">{event.resourceType}</span> · {m.actor}: <span dir="ltr">{event.actorType}</span></p><time className="mt-1 block text-sm text-muted-foreground" dateTime={event.occurredAt}>{m.occurredAt}: {formatter.format(new Date(event.occurredAt))}</time></div><dl className="min-w-0 space-y-2 text-xs"><div><dt className="font-medium">{m.correlation}</dt><dd className="break-all font-mono" dir="ltr">{event.correlationId}</dd></div><div><dt className="font-medium">{m.integrity}</dt><dd className="break-all font-mono" dir="ltr">{event.eventHash}</dd></div></dl></CardContent></Card>)}</div>}</section>
  </div>;
}
