"use client";

import { useActionState, useEffect, useRef, useState, type ReactNode } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { formatMinorExact } from "@/lib/client-rfq/model";
import { formatBasisPointsExact, isTaxRuleApplicable, taxRulesForCategory, type ProviderQuoteDashboard } from "@/lib/provider-quotes/model";
import { decideInvitation, saveQuoteRevision, submitQuote, type QuoteActionState } from "./actions";
import type { ProviderQuoteMessages } from "./messages";
import { quoteStatusLabel } from "./status-labels";
import type { QuotePrefill } from "./prefill";
import { rotateRevisionIdentity, rotateSubmitIdentity } from "./operation-identity";

const idle: QuoteActionState = { status: "idle" };
const draftFieldNames = ["solution","deliverables","inclusions","exclusions","prerequisites","warranty","correctionTerms","proposedStartDate","durationDays","validUntil","changeReason"] as const;
type QuoteLine = { key: number; label: string; quantity: string; unitCode: string; unitPrice: string; taxRuleVersionId: string; itemKind: "ONE_TIME" | "RECURRING"; recurrenceInterval: "" | "MONTH" | "QUARTER" | "YEAR" };
const emptyLine = (key: number): QuoteLine => ({ key, label:"", quantity:"1", unitCode:"FORFAIT", unitPrice:"", taxRuleVersionId:"", itemKind:"ONE_TIME", recurrenceInterval:"" });
type StoredDraft = { version: 2; expiresAt: number; fields: Record<string,string>; lines: QuoteLine[]; operation: { revision: string; correlation: string } };

function Feedback({ state, m }: { state: QuoteActionState; m: ProviderQuoteMessages }) {
  const label = state.status === "success" ? m.success : state.status === "error" ? (state.reason === "VALIDATION" ? m.validation : state.reason === "FORBIDDEN" ? m.forbidden : m.failed) : "";
  return <p role={state.status === "error" ? "alert" : "status"} aria-live="polite" className={state.status === "error" ? "text-sm text-destructive" : "text-sm text-primary"}>{label}</p>;
}
const Field = ({ label, name, children }: { label: string; name: string; children: ReactNode }) => <div className="grid min-w-0 gap-2"><label htmlFor={name} className="break-words text-sm font-medium">{label}</label>{children}</div>;

function Decision({ item, locale, m, identity }: { item:ProviderQuoteDashboard["invitations"][number];locale:"fr"|"ar";m:ProviderQuoteMessages;identity:{decision:string;correlation:string} }) {
  const [state, action, pending] = useActionState(decideInvitation, idle);
  return <form action={action} className="grid min-w-0 gap-3 rounded-xl border p-3"><input type="hidden" name="locale" value={locale}/><input type="hidden" name="invitationId" value={item.id}/><input type="hidden" name="rowVersion" value={item.rowVersion}/><input type="hidden" name="idempotencyKey" value={identity.decision}/><input type="hidden" name="correlationId" value={identity.correlation}/><Field label={m.reason} name={`reason-${item.id}`}><Input id={`reason-${item.id}`} name="reason" maxLength={500}/></Field><div className="flex flex-col gap-2 sm:flex-row"><Button name="decision" value="ACCEPT" disabled={pending} className="min-h-11 flex-1">{m.accept}</Button><Button name="decision" value="DECLINE" disabled={pending} variant="outline" className="min-h-11 flex-1">{m.decline}</Button></div><Feedback state={state} m={m}/></form>;
}

function validStoredDraft(value: unknown): value is StoredDraft {
  if (!value || typeof value !== "object") return false;
  const draft = value as Partial<StoredDraft>;
  return draft.version === 2 && typeof draft.expiresAt === "number" && draft.expiresAt > Date.now() && !!draft.fields && typeof draft.fields === "object" && !!draft.operation && typeof draft.operation.revision === "string" && typeof draft.operation.correlation === "string" && Array.isArray(draft.lines) && draft.lines.length > 0 && draft.lines.length <= 50 && draft.lines.every((line) => !!line && typeof line.label === "string" && typeof line.quantity === "string" && typeof line.unitPrice === "string");
}

function QuoteForm({ item, taxRules, organizationId, locale, m, identity, prefill }: { item:ProviderQuoteDashboard["invitations"][number];taxRules:ProviderQuoteDashboard["taxRules"];organizationId:string;locale:"fr"|"ar";m:ProviderQuoteMessages;identity:{revision:string;correlation:string};prefill?:QuotePrefill }) {
  const [state, action, pending] = useActionState(saveQuoteRevision, idle);
  const [score, setScore] = useState(0), [formValid, setFormValid] = useState(false), [effectiveOn, setEffectiveOn] = useState(prefill?.proposedStartDate??""), [draftStatus, setDraftStatus] = useState<""|"saved"|"restored"|"failed">("");
  const [operationIdentity, setOperationIdentity] = useState(identity);
  const initialLines:QuoteLine[]=prefill?.lines.length?prefill.lines.map((line,index)=>({key:index+1,...line})):[emptyLine(1)];
  const [quoteLines, setQuoteLines] = useState<QuoteLine[]>(()=>initialLines), counter = useRef(initialLines.length), formRef = useRef<HTMLFormElement>(null);
  const draftKey = `matricia:provider-quote-draft:v1:${organizationId}:${item.id}`;
  const applicableRules = taxRules.filter((rule) => isTaxRuleApplicable(rule, effectiveOn));
  const recompute = () => {
    const form = formRef.current; if (!form) return;
    const required = Array.from(form.querySelectorAll<HTMLInputElement|HTMLTextAreaElement|HTMLSelectElement>("[required]"));
    const valid = required.filter((control) => control.value.trim() !== "" && control.checkValidity()).length;
    setScore(required.length ? Math.round(valid * 10000 / required.length) : 0);
    setFormValid(required.length > 0 && valid === required.length);
    setEffectiveOn(String(new FormData(form).get("proposedStartDate") ?? ""));
  };
  useEffect(() => {
    const timer = window.setTimeout(() => {
      try {
        const raw = sessionStorage.getItem(draftKey); if (!raw || raw.length > 100_000) return;
        const parsed: unknown = JSON.parse(raw); if (!validStoredDraft(parsed)) { sessionStorage.removeItem(draftKey); return; }
        counter.current = Math.max(...parsed.lines.map((line) => line.key), 1); setQuoteLines(parsed.lines); setOperationIdentity(parsed.operation);
        window.setTimeout(() => { const form = formRef.current; if (!form) return; for (const name of draftFieldNames) { const control = form.elements.namedItem(name); if (control instanceof HTMLInputElement || control instanceof HTMLTextAreaElement) control.value = parsed.fields[name] ?? ""; } recompute(); setDraftStatus("restored"); }, 0);
      } catch { setDraftStatus("failed"); }
    }, 0);
    return () => window.clearTimeout(timer);
  }, [draftKey]);
  useEffect(() => { if (state.status === "success") { try { sessionStorage.removeItem(draftKey); } catch { /* server save succeeded; local cleanup is best effort */ } window.setTimeout(() => setOperationIdentity(rotateRevisionIdentity()), 0); } }, [draftKey, state]);
  useEffect(() => { window.setTimeout(recompute, 0); }, [quoteLines]);
  const updateLine = (key:number, patch:Partial<QuoteLine>) => setQuoteLines((current) => current.map((line) => line.key === key ? { ...line, ...patch } : line));
  const moveLine = (index:number, delta:number) => setQuoteLines((current) => { const target=index+delta;if(target<0||target>=current.length)return current;const next=[...current];[next[index],next[target]]=[next[target]!,next[index]!];return next; });
  const saveLocal = () => {
    const form = formRef.current; if (!form) return;
    try {
      const data = new FormData(form), fields = Object.fromEntries(draftFieldNames.map((name) => [name, String(data.get(name) ?? "")]));
      sessionStorage.setItem(draftKey, JSON.stringify({ version:2, expiresAt:Date.now()+7*24*60*60*1000, fields, lines:quoteLines, operation:operationIdentity } satisfies StoredDraft)); setDraftStatus("saved");
    } catch { setDraftStatus("failed"); }
  };
  return <form ref={formRef} action={action} onInput={recompute} onSubmit={saveLocal} className="grid min-w-0 gap-4 rounded-xl border p-4"><input type="hidden" name="locale" value={locale}/><input type="hidden" name="rfqProviderId" value={item.id}/><input type="hidden" name="currency" value={item.currency}/><input type="hidden" name="idempotencyKey" value={operationIdentity.revision}/><input type="hidden" name="correlationId" value={operationIdentity.correlation}/>
    <p className="rounded-lg bg-muted/60 p-3 text-sm text-muted-foreground">{m.draftNotice}</p>
    <div><div className="flex justify-between gap-3 text-sm font-medium"><span>{m.completeness}</span><output>{Math.floor(score/100)}%</output></div><progress className="mt-2 h-2 w-full" max={10000} value={score} aria-label={m.completeness}/></div>
    <Field label={m.solution} name={`solution-${item.id}`}><Textarea id={`solution-${item.id}`} name="solution" defaultValue={prefill?.solution} required minLength={3}/></Field><Field label={m.deliverables} name={`deliverables-${item.id}`}><Textarea id={`deliverables-${item.id}`} name="deliverables" defaultValue={prefill?.deliverables} required/></Field>
    <div className="grid min-w-0 gap-4 md:grid-cols-3"><Field label={m.inclusions} name={`inclusions-${item.id}`}><Textarea id={`inclusions-${item.id}`} name="inclusions" defaultValue={prefill?.inclusions}/></Field><Field label={m.exclusions} name={`exclusions-${item.id}`}><Textarea id={`exclusions-${item.id}`} name="exclusions" defaultValue={prefill?.exclusions}/></Field><Field label={m.prerequisites} name={`prerequisites-${item.id}`}><Textarea id={`prerequisites-${item.id}`} name="prerequisites" defaultValue={prefill?.prerequisites}/></Field></div>
    <div className="grid min-w-0 gap-4 sm:grid-cols-2"><Field label={m.warranty} name={`warranty-${item.id}`}><Input id={`warranty-${item.id}`} name="warranty" defaultValue={prefill?.warranty} required minLength={3}/></Field><Field label={m.corrections} name={`corrections-${item.id}`}><Input id={`corrections-${item.id}`} name="correctionTerms" defaultValue={prefill?.correctionTerms} required minLength={3}/></Field><Field label={m.start} name={`start-${item.id}`}><Input id={`start-${item.id}`} name="proposedStartDate" defaultValue={prefill?.proposedStartDate} type="date" required/></Field><Field label={m.duration} name={`duration-${item.id}`}><Input id={`duration-${item.id}`} name="durationDays" defaultValue={prefill?.durationDays} type="number" min={1} max={3650} required/></Field><Field label={m.validUntil} name={`valid-${item.id}`}><Input id={`valid-${item.id}`} name="validUntil" defaultValue={prefill?.validUntil} type="datetime-local" required/></Field></div>
    <fieldset className="min-w-0 space-y-3 rounded-xl bg-muted/50 p-3"><div className="flex flex-wrap items-center justify-between gap-3"><legend className="text-lg font-semibold">{m.priceLines}</legend><Button type="button" variant="outline" className="min-h-11" onClick={() => { counter.current += 1; setQuoteLines((current) => [...current, emptyLine(counter.current)]); }}>{m.addLine}</Button></div>
      {quoteLines.map((line,index) => <div key={line.key} className="grid min-w-0 gap-3 rounded-lg border bg-background p-3 sm:grid-cols-2 lg:grid-cols-4"><Field label={`${m.line} ${index+1}`} name={`line-${item.id}-${line.key}`}><Input id={`line-${item.id}-${line.key}`} name="lineLabel" value={line.label} onChange={(event)=>updateLine(line.key,{label:event.target.value})} required/></Field><Field label={m.quantity} name={`quantity-${item.id}-${line.key}`}><Input id={`quantity-${item.id}-${line.key}`} name="quantity" value={line.quantity} onChange={(event)=>updateLine(line.key,{quantity:event.target.value})} inputMode="decimal" dir="ltr" pattern="\d{1,14}(?:\.\d{1,4})?" required/></Field><Field label={m.unit} name={`unit-${item.id}-${line.key}`}><Input id={`unit-${item.id}-${line.key}`} name="unitCode" value={line.unitCode} onChange={(event)=>updateLine(line.key,{unitCode:event.target.value.toUpperCase()})} dir="ltr" required/></Field><Field label={`${m.unitPrice} (${item.currency})`} name={`price-${item.id}-${line.key}`}><Input id={`price-${item.id}-${line.key}`} name="unitPrice" value={line.unitPrice} onChange={(event)=>updateLine(line.key,{unitPrice:event.target.value})} inputMode="decimal" dir="ltr" aria-describedby={`price-help-${item.id}`} required/></Field><Field label={m.tax} name={`tax-${item.id}-${line.key}`}><select id={`tax-${item.id}-${line.key}`} name="taxRuleVersionId" value={line.taxRuleVersionId} onChange={(event)=>updateLine(line.key,{taxRuleVersionId:event.target.value})} required className="min-h-11 w-full min-w-0 max-w-full rounded-md border bg-background px-3"><option value="">—</option>{applicableRules.map((rule)=><option key={rule.id} value={rule.id}>{rule.category} · {formatBasisPointsExact(rule.rateBasisPoints)}%</option>)}</select></Field><Field label={m.kind} name={`kind-${item.id}-${line.key}`}><select id={`kind-${item.id}-${line.key}`} name="itemKind" value={line.itemKind} onChange={(event)=>updateLine(line.key,{itemKind:event.target.value as QuoteLine["itemKind"],recurrenceInterval:event.target.value === "ONE_TIME" ? "" : line.recurrenceInterval})} className="min-h-11 w-full rounded-md border bg-background px-3"><option value="ONE_TIME">{m.oneTime}</option><option value="RECURRING">{m.recurring}</option></select></Field><Field label={m.interval} name={`interval-${item.id}-${line.key}`}><select id={`interval-${item.id}-${line.key}`} name="recurrenceInterval" value={line.recurrenceInterval} onChange={(event)=>updateLine(line.key,{recurrenceInterval:event.target.value as QuoteLine["recurrenceInterval"]})} required={line.itemKind === "RECURRING"} disabled={line.itemKind !== "RECURRING"} className="min-h-11 w-full rounded-md border bg-background px-3"><option value="">—</option><option value="MONTH">{m.month}</option><option value="QUARTER">{m.quarter}</option><option value="YEAR">{m.year}</option></select></Field><div className="flex flex-wrap items-end gap-2"><Button type="button" variant="outline" className="min-h-11" disabled={index===0} onClick={()=>moveLine(index,-1)} aria-label={`${m.moveUp} ${index+1}`}>↑</Button><Button type="button" variant="outline" className="min-h-11" disabled={index===quoteLines.length-1} onClick={()=>moveLine(index,1)} aria-label={`${m.moveDown} ${index+1}`}>↓</Button><Button type="button" variant="outline" className="min-h-11" disabled={quoteLines.length===1} onClick={()=>setQuoteLines((current)=>current.filter((value)=>value.key!==line.key))}>{m.removeLine}</Button></div></div>)}
      <p id={`price-help-${item.id}`} className="text-sm text-muted-foreground">{m.priceHelp}</p>
    </fieldset>
    <Field label={m.changeReason} name={`change-${item.id}`}><Input id={`change-${item.id}`} name="changeReason" defaultValue={prefill?.changeReason} required minLength={3}/></Field>
    <div className="flex flex-col gap-2 sm:flex-row"><Button type="button" variant="outline" disabled={pending} className="min-h-11" onClick={saveLocal}>{m.saveLocal}</Button><Button disabled={pending || !formValid || applicableRules.length===0} className="min-h-11">{pending?m.saving:m.save}</Button></div>
    {draftStatus?<p role={draftStatus==="failed"?"alert":"status"} aria-live="polite" className={draftStatus==="failed"?"text-sm text-destructive":"text-sm text-primary"}>{draftStatus==="saved"?m.localSaved:draftStatus==="restored"?m.localRestored:m.localFailed}</p>:null}
    {applicableRules.length===0?<p role="alert" className="text-sm text-destructive">{m.noTax}</p>:!formValid?<p role="status" className="text-sm text-muted-foreground">{m.validation}</p>:null}<Feedback state={state} m={m}/>
  </form>;
}

function Submit({ item, locale, m, identity }: { item:ProviderQuoteDashboard["invitations"][number];locale:"fr"|"ar";m:ProviderQuoteMessages;identity:{submit:string;correlation:string} }) {
  const [state, action, pending] = useActionState(submitQuote, idle);
  const quoteVersionId = item.quote?.currentVersionId ?? "";
  const submitKey = `matricia:provider-quote-submit:v1:${quoteVersionId}`;
  const [submitIdentity, setSubmitIdentity] = useState(identity);
  useEffect(() => {
    if (!quoteVersionId) return;
    try {
      const raw = sessionStorage.getItem(submitKey);
      if (raw) { const parsed = JSON.parse(raw) as Partial<typeof identity>; if (typeof parsed.submit === "string" && typeof parsed.correlation === "string") window.setTimeout(() => setSubmitIdentity({ submit:parsed.submit!, correlation:parsed.correlation! }), 0); }
      else sessionStorage.setItem(submitKey, JSON.stringify(identity));
    } catch { /* the server still enforces idempotence for the current request */ }
  }, [identity, quoteVersionId, submitKey]);
  useEffect(() => { if (state.status === "success") { try { sessionStorage.removeItem(submitKey); } catch { /* best effort */ } window.setTimeout(() => setSubmitIdentity(rotateSubmitIdentity()), 0); } }, [state, submitKey]);
  if (!item.quote?.currentVersionId || !["DRAFT","REVISED"].includes(item.quote.status)) return null;
  return <form action={action} className="min-w-0 space-y-2"><input type="hidden" name="locale" value={locale}/><input type="hidden" name="quoteId" value={item.quote.id}/><input type="hidden" name="quoteVersionId" value={item.quote.currentVersionId}/><input type="hidden" name="idempotencyKey" value={submitIdentity.submit}/><input type="hidden" name="correlationId" value={submitIdentity.correlation}/><Button disabled={pending} className="min-h-11 w-full sm:w-fit">{pending?m.saving:m.submit}</Button><Feedback state={state} m={m}/></form>;
}

export function QuotePanel({ dashboard, locale, m, identities, prefills={} }: { dashboard:ProviderQuoteDashboard;locale:"fr"|"ar";m:ProviderQuoteMessages;identities:Record<string,{decision:string;revision:string;submit:string;correlation:string}>;prefills?:Record<string,QuotePrefill> }) {
  return <div className="min-w-0 space-y-5"><p className="rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm">{m.privacy}</p>{dashboard.invitations.length===0?<p role="status" className="rounded-xl border bg-card p-5 text-muted-foreground">{m.empty}</p>:dashboard.invitations.map((item)=>{const taxRules=taxRulesForCategory(dashboard.taxRules,item.taxCategoryCode);return <Card key={item.id} className="min-w-0"><CardHeader className="min-w-0"><div className="flex min-w-0 flex-wrap justify-between gap-3"><CardTitle className="min-w-0 break-words">{item.description}</CardTitle><Badge>{quoteStatusLabel(item.status,locale)}</Badge></div></CardHeader><CardContent className="min-w-0 space-y-5"><dl className="grid gap-2 text-sm sm:grid-cols-2"><div><dt className="text-muted-foreground">{m.deadline}</dt><dd>{new Intl.DateTimeFormat(locale==="ar"?"ar-MA":"fr-MA",{dateStyle:"medium"}).format(new Date(item.deadline))}</dd></div><div><dt className="text-muted-foreground">{m.region}</dt><dd>{item.regionCode}</dd></div></dl>{item.quote?<div className="min-w-0 rounded-xl bg-muted/50 p-3 text-sm"><p>{m.current}: {item.quote.versionNumber??"—"} · {quoteStatusLabel(item.quote.status,locale)}</p>{item.quote.totalMinor!==null?<p dir="ltr" className="mt-1 min-w-0 [overflow-wrap:anywhere] font-semibold">{m.subtotal} {formatMinorExact(item.quote.subtotalMinor!,item.currency,locale)} · {m.taxAmount} {formatMinorExact(item.quote.taxMinor!,item.currency,locale)} · {m.total} {formatMinorExact(item.quote.totalMinor,item.currency,locale)}</p>:null}</div>:null}{dashboard.canManage&&item.status==="INVITED"?<Decision item={item} locale={locale} m={m} identity={identities[item.id]!}/>:null}{dashboard.canManage&&item.status==="ACCEPTED"?(item.taxCategoryCode&&taxRules.length>0?<QuoteForm item={item} taxRules={taxRules} organizationId={dashboard.organizationId} locale={locale} m={m} identity={identities[item.id]!} prefill={prefills[item.id]}/>:<p role="alert" className="rounded-xl border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">{m.taxConfigurationMissing}</p>):null}{dashboard.canManage?<Submit item={item} locale={locale} m={m} identity={identities[item.id]!}/>:<p>{m.readOnly}</p>}</CardContent></Card>})}</div>;
}
