"use client";

import { useActionState, useState } from "react";
import { Button } from "@/components/ui/button";
import type { AssistanceCandidate, AssistanceDashboard, AssistanceSuggestion } from "@/lib/assisted-intelligence/contracts";
import { compareAnomalies, decideSuggestion, idleAssistanceAction, runAnalysis, type AssistanceActionState } from "./actions";
import type { AssistanceMessages } from "./messages";

type Keys = { analysis: string; similarity: string; decisions: Record<string, string> };
type Props = { dashboard: AssistanceDashboard; locale: "fr" | "ar"; messages: AssistanceMessages; keys: Keys };

function Feedback({ state, messages }: { state: AssistanceActionState; messages: AssistanceMessages }) {
  if (state.status === "idle") return null;
  if (state.status === "success") {
    const message = typeof state.suggestionCount === "number" ? messages.runSuccess.replace("{count}", String(state.suggestionCount)) : messages.decided;
    return <p role="status" aria-live="polite" className="rounded-lg border border-primary/25 bg-primary/5 p-3 text-sm text-primary">{message}</p>;
  }
  const message = state.reason === "VALIDATION" ? messages.validation : state.reason === "FORBIDDEN" || state.reason === "UNAUTHENTICATED" ? messages.forbiddenAction : state.reason === "CONFLICT" ? messages.conflict : messages.failed;
  return <p role="alert" className="rounded-lg border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">{message}</p>;
}

function Field({ id, label, hint, children }: { id: string; label: string; hint?: string; children: React.ReactNode }) {
  return <div className="grid min-w-0 gap-1.5"><label htmlFor={id} className="text-sm font-medium">{label}</label>{children}{hint ? <p id={`${id}-hint`} className="text-xs leading-5 text-muted-foreground">{hint}</p> : null}</div>;
}

function OrganizationSelect({ id, dashboard, messages, value, onChange }: { id: string; dashboard: AssistanceDashboard; messages: AssistanceMessages; value: string; onChange: (value: string) => void }) {
  return <Field id={id} label={messages.organization}><select id={id} name="organizationId" required value={value} onChange={(event)=>onChange(event.currentTarget.value)} className="min-h-11 w-full rounded-md border bg-background px-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{dashboard.organizations.map((organization) => <option key={organization.id} value={organization.id}>{organization.name}</option>)}</select></Field>;
}

function CandidateSelect({ id, name, label, candidates, locale, messages, required = false }: { id: string; name: string; label: string; candidates: AssistanceCandidate[]; locale: "fr" | "ar"; messages: AssistanceMessages; required?: boolean }) {
  return <Field id={id} label={label} hint={messages.multiSelectHelp}><select id={id} name={name} multiple required={required} size={Math.min(6, Math.max(2, candidates.length))} disabled={!candidates.length} aria-describedby={`${id}-hint`} className="min-h-24 w-full rounded-md border bg-background px-2 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{candidates.length ? candidates.map((candidate) => <option key={`${candidate.organizationId}-${candidate.id}`} value={candidate.id}>{locale === "ar" ? candidate.labelAr : candidate.labelFr} · {candidate.detail}</option>) : <option>{messages.noCandidates}</option>}</select></Field>;
}

function DecisionForm({ suggestion, canDecide, locale, messages, idempotencyKey }: { suggestion: AssistanceSuggestion; canDecide: boolean; locale: "fr" | "ar"; messages: AssistanceMessages; idempotencyKey: string }) {
  const [state, action, pending] = useActionState(decideSuggestion, idleAssistanceAction);
  const rationaleId = `rationale-${suggestion.id}`;
  if (suggestion.status !== "PROPOSED") return <p className="mt-4 rounded-lg bg-muted p-3 text-sm" role="status">{messages.decided}</p>;
  if (!canDecide) return <p className="mt-4 rounded-lg border p-3 text-sm text-muted-foreground">{messages.forbiddenAction}</p>;
  return <form action={action} className="mt-4 grid gap-3 border-t pt-4">
    <input type="hidden" name="locale" value={locale}/><input type="hidden" name="suggestionId" value={suggestion.id}/><input type="hidden" name="idempotencyKey" value={idempotencyKey}/>
    <Field id={rationaleId} label={messages.rationale}><textarea id={rationaleId} name="rationale" required minLength={3} maxLength={1000} rows={3} className="w-full resize-y rounded-md border bg-background px-3 py-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"/></Field>
    <div className="grid gap-2 sm:grid-cols-2"><Button name="decision" value="ACCEPTED" disabled={pending} className="min-h-11 w-full">{messages.accept}</Button><Button name="decision" value="REJECTED" variant="outline" disabled={pending} className="min-h-11 w-full">{messages.reject}</Button></div>
    <Feedback state={state} messages={messages}/>
  </form>;
}

export function AssistancePanel({ dashboard, locale, messages, keys }: Props) {
  const [analysisState, analysisAction, analysisPending] = useActionState(runAnalysis, idleAssistanceAction);
  const [similarityState, similarityAction, similarityPending] = useActionState(compareAnomalies, idleAssistanceAction);
  const [analysisOrganization, setAnalysisOrganization] = useState(dashboard.organizations[0]?.id ?? "");
  const [similarityOrganization, setSimilarityOrganization] = useState(dashboard.organizations[0]?.id ?? "");
  const model = dashboard.model;
  return <div className="space-y-6">
    <section aria-labelledby="analysis-title" className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6">
      <h2 id="analysis-title" className="text-xl font-semibold text-foreground">{messages.analysisTitle}</h2><p className="mt-2 max-w-3xl text-sm leading-6 text-muted-foreground">{messages.analysisHelp}</p>
      {model ? <form action={analysisAction} className="mt-5 grid min-w-0 gap-4 md:grid-cols-2">
        <input type="hidden" name="locale" value={locale}/><input type="hidden" name="modelVersionId" value={model.id}/><input type="hidden" name="idempotencyKey" value={keys.analysis}/>
        <OrganizationSelect id="analysis-organization" dashboard={dashboard} messages={messages} value={analysisOrganization} onChange={setAnalysisOrganization}/>
        <Field id="analysis-context" label={messages.context}><select id="analysis-context" name="context" className="min-h-11 w-full rounded-md border bg-background px-3">{Object.entries(messages.contexts).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></Field>
        <div className="md:col-span-2"><Field id="analysis-text" label={`${messages.inputText} (${messages.optional})`} hint={messages.inputTextHelp}><textarea id="analysis-text" name="inputText" maxLength={1000} rows={4} aria-describedby="analysis-text-hint" className="w-full resize-y rounded-md border bg-background px-3 py-2"/></Field></div>
        <CandidateSelect id="service-version-ids" name="serviceVersionIds" label={`${messages.serviceIds} (${messages.optional})`} candidates={dashboard.serviceCandidates.filter((candidate)=>candidate.organizationId===analysisOrganization)} locale={locale} messages={messages}/>
        <CandidateSelect id="question-version-ids" name="questionVersionIds" label={`${messages.questionIds} (${messages.optional})`} candidates={dashboard.questionCandidates.filter((candidate)=>candidate.organizationId===analysisOrganization)} locale={locale} messages={messages}/>
        <Field id="known-data-keys" label={`${messages.knownKeys} (${messages.optional})`}><textarea id="known-data-keys" name="knownDataKeys" rows={2} dir="ltr" spellCheck={false} className="w-full resize-y rounded-md border bg-background px-3 py-2 font-mono text-sm"/></Field>
        <Field id="profile-reassessment-id" label={`${messages.reassessmentId} (${messages.optional})`}><select id="profile-reassessment-id" name="profileReassessmentId" className="min-h-11 w-full rounded-md border bg-background px-3 text-sm"><option value="">{messages.noReassessment}</option>{dashboard.reassessmentCandidates.filter((candidate)=>candidate.organizationId===analysisOrganization).map((candidate)=><option key={candidate.id} value={candidate.id}>{locale==="ar"?candidate.labelAr:candidate.labelFr} · {candidate.detail}</option>)}</select></Field>
        <div className="grid gap-3 md:col-span-2"><Button disabled={analysisPending} className="min-h-11 w-full sm:w-auto sm:justify-self-start">{messages.analyze}</Button><Feedback state={analysisState} messages={messages}/></div>
      </form> : <p role="status" className="mt-5 rounded-xl border p-4 text-sm">{messages.unavailableModel}</p>}
    </section>

    <section aria-labelledby="similarity-title" className="rounded-2xl border bg-card p-4 shadow-sm sm:p-6">
      <h2 id="similarity-title" className="text-xl font-semibold">{messages.similarityTitle}</h2><p className="mt-2 text-sm leading-6 text-muted-foreground">{messages.similarityHelp}</p>
      {model ? <form action={similarityAction} className="mt-5 grid gap-4 md:grid-cols-2"><input type="hidden" name="locale" value={locale}/><input type="hidden" name="modelVersionId" value={model.id}/><input type="hidden" name="idempotencyKey" value={keys.similarity}/><OrganizationSelect id="similarity-organization" dashboard={dashboard} messages={messages} value={similarityOrganization} onChange={setSimilarityOrganization}/><CandidateSelect id="anomaly-ids" name="anomalyIds" label={messages.anomalyIds} candidates={dashboard.anomalyCandidates.filter((candidate)=>candidate.organizationId===similarityOrganization)} locale={locale} messages={messages} required/><div className="grid gap-3 md:col-span-2"><Button disabled={similarityPending || dashboard.anomalyCandidates.filter((candidate)=>candidate.organizationId===similarityOrganization).length < 2} className="min-h-11 w-full sm:w-auto sm:justify-self-start">{messages.compare}</Button><Feedback state={similarityState} messages={messages}/></div></form> : null}
    </section>

    <section aria-labelledby="suggestions-title"><h2 id="suggestions-title" className="text-xl font-semibold">{messages.suggestionsTitle}</h2>
      {!dashboard.suggestions.length ? <p className="mt-3 rounded-xl border bg-card p-5 text-muted-foreground">{messages.noSuggestions}</p> : <div className="mt-3 grid gap-4 lg:grid-cols-2">{dashboard.suggestions.map((suggestion) => {
        const organization = dashboard.organizations.find((item) => item.id === suggestion.organizationId);
        return <article key={suggestion.id} className="min-w-0 rounded-2xl border bg-card p-4 shadow-sm sm:p-5"><div className="flex flex-wrap items-start justify-between gap-2"><h3 className="font-semibold">{messages.kinds[suggestion.kind] ?? suggestion.kind}</h3><span className="rounded-full border px-2.5 py-1 text-xs font-medium">{messages.status}: {messages.statuses[suggestion.status]}</span></div><p className="mt-2 text-sm font-medium text-primary">{messages.humanRequired}</p><p className="mt-1 text-xs text-muted-foreground">{messages.provenance}: <span dir="ltr" className="font-mono">v{suggestion.modelVersion} · {suggestion.explanationCode}</span></p><dl className="mt-4 grid gap-2 text-sm"><div className="flex flex-wrap justify-between gap-2"><dt>{messages.score}</dt><dd>{new Intl.NumberFormat(locale, { style: "percent", maximumFractionDigits: 1 }).format(suggestion.scoreBasisPoints / 10000)}</dd></div><div className="min-w-0"><dt>{messages.target}</dt><dd dir="ltr" className="break-all font-mono text-xs">{suggestion.targetType} · {suggestion.targetId ?? "PROFILE"}</dd></div>{suggestion.relatedTargetId ? <div className="min-w-0"><dt>{messages.relatedTarget}</dt><dd dir="ltr" className="break-all font-mono text-xs">{suggestion.relatedTargetId}</dd></div> : null}</dl><details className="mt-4 rounded-lg border p-3"><summary className="cursor-pointer font-medium focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{messages.evidence}</summary><pre dir="ltr" className="mt-2 overflow-x-auto whitespace-pre-wrap break-words text-xs">{JSON.stringify(suggestion.evidence, null, 2)}</pre></details><DecisionForm suggestion={suggestion} canDecide={organization?.canDecide ?? false} locale={locale} messages={messages} idempotencyKey={keys.decisions[suggestion.id]}/></article>;
      })}</div>}
    </section>

    <section aria-labelledby="history-title"><h2 id="history-title" className="text-xl font-semibold">{messages.histories}</h2>{!dashboard.requests.length ? <p className="mt-3 rounded-xl border bg-card p-5 text-muted-foreground">{messages.noHistory}</p> : <ul className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{dashboard.requests.map((request) => <li key={request.id} className="min-w-0 rounded-xl border bg-card p-4"><div className="flex flex-wrap justify-between gap-2"><strong>{messages.contexts[request.context]}</strong><span className="text-sm">{messages.statuses[request.status]}</span></div><p className="mt-2 text-sm text-muted-foreground">{new Intl.DateTimeFormat(locale, { dateStyle: "medium", timeStyle: "short" }).format(new Date(request.createdAt))}</p><p dir="ltr" className="mt-2 break-all font-mono text-xs">{request.id}</p></li>)}</ul>}</section>
  </div>;
}
