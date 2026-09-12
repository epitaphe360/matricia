"use client";
import { useActionState, useId, useState, type FormEvent, type ReactNode } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import type { Locale } from "@/lib/i18n/locale";
import { formatMinor, type MarketingDashboard } from "@/lib/marketing-autopilot/model";
import { approveCampaign, createCampaign, recordConsent, scheduleCampaign, type MarketingActionState } from "./actions";
import type { MarketingMessages } from "./messages";

const idle: MarketingActionState = { status: "idle" };
const control = "min-h-11 w-full rounded-md border bg-background px-3 text-base";
function localized(values: Record<string, string>, code: string, unknown: string) { return values[code] ?? unknown; }
function Field({ id, label, children }: { id: string; label: string; children: ReactNode }) { return <div className="min-w-0 space-y-2"><Label htmlFor={id}>{label}</Label>{children}</div>; }
function Hidden({ locale, keyValue }: { locale: Locale; keyValue: string }) { return <><input type="hidden" name="locale" value={locale}/><input type="hidden" name="idempotencyKey" value={keyValue}/></>; }
function Feedback({ state, m }: { state: MarketingActionState; m: MarketingMessages }) { const message = state.status === "success" ? m.success : state.status === "error" ? state.reason === "VALIDATION" ? m.validation : state.reason === "FORBIDDEN" ? m.forbidden : state.reason === "CONFLICT" ? m.conflict : m.failed : ""; return <p role={state.status === "error" ? "alert" : "status"} aria-live="polite" className={`min-h-5 text-sm ${state.status === "error" ? "text-destructive" : "text-primary"}`}>{message}</p>; }
function Submit({ pending, label, m }: { pending: boolean; label: string; m: MarketingMessages }) { return <Button disabled={pending} className="min-h-11 w-full sm:w-auto">{pending ? m.pending : label}</Button>; }
function Select({ id, label, name, values }: { id: string; label: string; name: string; values: Array<[string, string]> }) { return <Field id={id} label={label}><select id={id} name={name} required className={control}>{values.map(([value, text]) => <option key={value} value={value}>{text}</option>)}</select></Field>; }
function Datum({ label, value }: { label: string; value: string }) { return <div><dt className="text-muted-foreground">{label}</dt><dd className="mt-1 font-medium" dir="auto">{value}</dd></div>; }

export function MarketingPanel({ dashboard, locale, m, keys }: { dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages; keys: Record<string, string> }) {
  const root = useId();
  return <div className="space-y-7">
    <section aria-labelledby={`${root}-safe`} className="rounded-2xl border border-primary/30 bg-primary/5 p-4 shadow-sm sm:p-6"><h2 id={`${root}-safe`} className="text-xl font-semibold">{m.safety}</h2><p className="mt-2 leading-7">{m.safetyText}</p></section>
    <div className="grid gap-5 xl:grid-cols-2"><ConsentForm dashboard={dashboard} locale={locale} m={m} keyValue={keys.consent}/><CampaignForm dashboard={dashboard} locale={locale} m={m} keyValue={keys.campaign}/></div>
    <ContentReview dashboard={dashboard} m={m}/>
    <div className="grid gap-5 xl:grid-cols-2"><Approvals dashboard={dashboard} locale={locale} m={m} keys={keys}/><Schedules dashboard={dashboard} locale={locale} m={m} keys={keys}/></div>
    <CampaignList dashboard={dashboard} locale={locale} m={m}/>
  </div>;
}

function ConsentForm({ dashboard, locale, m, keyValue }: { dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages; keyValue: string }) {
  const id = useId(), [state, action, pending] = useActionState(recordConsent, idle);
  return <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><h2 className="text-xl font-semibold">{m.consent}</h2><form action={action} className="mt-4 grid gap-3 sm:grid-cols-2">
    <Hidden locale={locale} keyValue={keyValue}/>
    <Select id={`${id}-org`} label={m.organization} name="organizationId" values={dashboard.organizations.map(value => [value.id, value.name])}/>
    <Select id={`${id}-purpose`} label={m.purpose} name="purpose" values={Object.entries(m.codes.purposes)}/>
    <Select id={`${id}-decision`} label={m.decision} name="decision" values={[["GRANTED", m.grant], ["WITHDRAWN", m.withdraw]]}/>
    <Field id={`${id}-policy`} label={m.policy}><Input id={`${id}-policy`} name="policyVersion" required maxLength={100} className={control}/></Field>
    <div className="sm:col-span-2"><Field id={`${id}-evidence`} label={m.evidence}><Input id={`${id}-evidence`} name="evidenceHash" required pattern="[0-9a-fA-F]{64}" className={control} dir="ltr"/></Field></div>
    <div className="sm:col-span-2"><Submit pending={pending} label={m.submit} m={m}/><Feedback state={state} m={m}/></div>
  </form></section>;
}

function CampaignForm({ dashboard, locale, m, keyValue }: { dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages; keyValue: string }) {
  const id = useId(), [state, action, pending] = useActionState(createCampaign, idle), ready = dashboard.brandVersions.filter(value => value.status === "READY");
  if (!ready.length) return <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><h2 className="text-xl font-semibold">{m.campaign}</h2><p className="mt-3 text-muted-foreground">{m.empty}</p></section>;
  return <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><h2 className="text-xl font-semibold">{m.campaign}</h2><form action={action} className="mt-4 grid gap-3 sm:grid-cols-2">
    <Hidden locale={locale} keyValue={keyValue}/>
    <Select id={`${id}-org`} label={m.organization} name="organizationId" values={dashboard.organizations.map(value => [value.id, value.name])}/>
    <Select id={`${id}-brand`} label={m.brand} name="brandKitVersionId" values={ready.map(value => [value.id, `${value.tradeName} · v${value.version}`])}/>
    <Select id={`${id}-mode`} label={m.mode} name="mode" values={Object.entries(m.codes.modes)}/>
    <Field id={`${id}-frequency`} label={m.frequency}><Input id={`${id}-frequency`} name="frequencyMaxWeekly" type="number" min={1} max={50} defaultValue={8} required className={control}/></Field>
    <Field id={`${id}-fr`} label={m.titleFr}><Input id={`${id}-fr`} name="titleFr" minLength={3} maxLength={200} required className={control}/></Field>
    <Field id={`${id}-ar`} label={m.titleAr}><Input id={`${id}-ar`} name="titleAr" minLength={2} maxLength={200} required className={control} dir="rtl"/></Field>
    <Field id={`${id}-risk`} label={m.risk}><Input id={`${id}-risk`} name="riskThreshold" type="number" min={0} max={100} defaultValue={20} required className={control}/></Field><div/>
    <Field id={`${id}-audience`} label={m.audience}><Textarea id={`${id}-audience`} name="audienceSnapshot" defaultValue='{"segment":"AGGREGATED","minimum_size":10}' required className="min-h-28" dir="ltr"/></Field>
    <Field id={`${id}-source`} label={m.source}><Textarea id={`${id}-source`} name="sourceSnapshot" defaultValue='{"source":"CATALOG","version":1}' required className="min-h-28" dir="ltr"/></Field>
    <div className="sm:col-span-2"><Submit pending={pending} label={m.submit} m={m}/><Feedback state={state} m={m}/></div>
  </form></section>;
}

function ContentReview({ dashboard, m }: { dashboard: MarketingDashboard; m: MarketingMessages }) {
  const id = useId(), [draft, setDraft] = useState(dashboard.contents[0]?.versionId ?? ""), [selected, setSelected] = useState(dashboard.contents[0]?.versionId ?? ""), value = dashboard.contents.find(content => content.versionId === selected);
  function submit(event: FormEvent) { event.preventDefault(); setSelected(draft); }
  return <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><h2 className="text-xl font-semibold">{m.content}</h2>{dashboard.contents.length ? <>
    <form onSubmit={submit} className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end"><div className="min-w-0 flex-1"><Field id={`${id}-content`} label={m.contentChoice}><select id={`${id}-content`} value={draft} onChange={event => setDraft(event.target.value)} className={control}>{dashboard.contents.map(content => <option key={content.versionId} value={content.versionId}>{m.codes.channels[content.channel]} · {m.codes.languages[content.language]} · {localized(m.codes.statuses, content.status, m.codes.unknown)}</option>)}</select></Field></div><Button className="min-h-11 w-full sm:w-auto">{m.show}</Button></form>
    {value ? <article aria-live="polite" className="mt-4 rounded-xl border p-4"><div className="flex flex-wrap justify-between gap-2"><strong>{m.codes.channels[value.channel]} · {m.codes.languages[value.language]}</strong><span>{m.riskScore}: {value.riskScore}/100 · {localized(m.codes.statuses, value.status, m.codes.unknown)}</span></div><h3 className="mt-4 font-semibold">{m.hook}</h3><p className="mt-1 whitespace-pre-wrap">{value.hook}</p><h3 className="mt-4 font-semibold">{m.body}</h3><p className="mt-1 whitespace-pre-wrap">{value.body}</p><p className="mt-4"><strong>{m.cta}:</strong> {value.cta}</p><p className="mt-2 text-sm text-muted-foreground" dir="ltr">{value.hashtags.join(" ")}</p></article> : null}
  </> : <p className="mt-3 text-muted-foreground">{m.noContent}</p>}</section>;
}

function Approvals({ dashboard, locale, m, keys }: { dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages; keys: Record<string, string> }) {
  const campaigns = dashboard.campaigns.filter(value => value.status === "VALIDATED_BY_RULES");
  return <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><h2 className="text-xl font-semibold">{m.approval}</h2><div className="mt-4 space-y-3">{campaigns.map(campaign => <ApprovalForm key={campaign.id} campaign={campaign} locale={locale} m={m} keyValue={keys[`approve:${campaign.id}`]}/>)}{!campaigns.length ? <p className="text-muted-foreground">{m.noApproval}</p> : null}</div></section>;
}
function ApprovalForm({ campaign, locale, m, keyValue }: { campaign: MarketingDashboard["campaigns"][number]; locale: Locale; m: MarketingMessages; keyValue: string }) {
  const [state, action, pending] = useActionState(approveCampaign, idle);
  return <form action={action} className="rounded-xl border p-3"><Hidden locale={locale} keyValue={keyValue}/><input type="hidden" name="campaignId" value={campaign.id}/><input type="hidden" name="rowVersion" value={campaign.rowVersion}/><p className="font-semibold">{locale === "ar" ? campaign.titleAr : campaign.titleFr}</p><p className="mt-1 text-sm text-muted-foreground">{m.risk}: {campaign.riskThreshold}</p><div className="mt-3"><Submit pending={pending} label={m.approve} m={m}/><Feedback state={state} m={m}/></div></form>;
}

function Schedules({ dashboard, locale, m, keys }: { dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages; keys: Record<string, string> }) {
  const campaigns = dashboard.campaigns.filter(value => value.status === "APPROVED");
  return <section className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><h2 className="text-xl font-semibold">{m.schedule}</h2><p className="mt-2 text-sm text-muted-foreground">{m.utc}</p><div className="mt-4 space-y-3">{campaigns.map(campaign => <ScheduleForm key={campaign.id} campaign={campaign} dashboard={dashboard} locale={locale} m={m} keyValue={keys[`schedule:${campaign.id}`]}/>)}{!campaigns.length ? <p className="text-muted-foreground">{m.noSchedule}</p> : null}</div></section>;
}
function ScheduleForm({ campaign, dashboard, locale, m, keyValue }: { campaign: MarketingDashboard["campaigns"][number]; dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages; keyValue: string }) {
  const id = useId(), [state, action, pending] = useActionState(scheduleCampaign, idle), contents = dashboard.contents.filter(value => value.campaignId === campaign.id && value.status === "APPROVED"), connections = dashboard.connections.filter(value => value.organizationId === campaign.organizationId && value.status === "ACTIVE");
  if (!contents.length || !connections.length) return null;
  return <form action={action} className="grid gap-3 rounded-xl border p-3"><Hidden locale={locale} keyValue={keyValue}/><input type="hidden" name="campaignId" value={campaign.id}/><input type="hidden" name="rowVersion" value={campaign.rowVersion}/><p className="font-semibold">{locale === "ar" ? campaign.titleAr : campaign.titleFr}</p><Select id={`${id}-content`} label={m.contentChoice} name="contentVersionId" values={contents.map(content => [content.versionId, `${m.codes.channels[content.channel]} · ${m.codes.languages[content.language]}`])}/><Select id={`${id}-connection`} label={m.connection} name="socialConnectionId" values={connections.map(connection => [connection.id, m.codes.providers[connection.provider]])}/><Field id={`${id}-date`} label={m.scheduledAt}><Input id={`${id}-date`} name="scheduledAt" type="datetime-local" required className={control}/></Field><Submit pending={pending} label={m.submit} m={m}/><Feedback state={state} m={m}/></form>;
}

function CampaignList({ dashboard, locale, m }: { dashboard: MarketingDashboard; locale: Locale; m: MarketingMessages }) {
  return <section><h2 className="text-2xl font-semibold">{m.campaigns}</h2><div className="mt-4 grid gap-4 lg:grid-cols-2">{dashboard.campaigns.map(campaign => { const performance = dashboard.performance.find(value => value.campaignId === campaign.id); return <article key={campaign.id} className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6"><div className="flex flex-wrap justify-between gap-2"><h3 className="text-xl font-semibold">{locale === "ar" ? campaign.titleAr : campaign.titleFr}</h3><span className="rounded-full border px-3 py-1 text-sm">{localized(m.codes.statuses, campaign.status, m.codes.unknown)}</span></div><dl className="mt-4 grid grid-cols-2 gap-3 text-sm sm:grid-cols-4"><Datum label={m.generated} value={performance?.generated ?? "0"}/><Datum label={m.published} value={performance?.published ?? "0"}/><Datum label={m.failedPublications} value={performance?.failed ?? "0"}/><Datum label={m.impressions} value={performance?.impressions ?? "0"}/><Datum label={m.clicks} value={performance?.clicks ?? "0"}/><Datum label={m.leads} value={performance?.leads ?? "0"}/><Datum label={m.diagnostics} value={performance?.diagnostics ?? "0"}/><Datum label={m.opportunities} value={performance?.opportunities ?? "0"}/><Datum label={m.rfqs} value={performance?.rfqs ?? "0"}/><Datum label={m.contracts} value={performance?.contracts ?? "0"}/><Datum label={m.value} value={formatMinor(performance?.attributedValueMinor ?? "0", "MAD", locale)}/><Datum label={m.cost} value={formatMinor(performance?.marketingCostMinor ?? "0", "MAD", locale)}/><Datum label={m.feedback} value={performance ? localized(m.codes.feedback, performance.feedback, m.codes.unknown) : m.codes.feedback.KEEP}/></dl></article>; })}{!dashboard.campaigns.length ? <p className="text-muted-foreground">{m.empty}</p> : null}</div></section>;
}
