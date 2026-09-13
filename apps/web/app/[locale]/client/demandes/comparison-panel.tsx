"use client";
import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { Card,CardContent,CardHeader,CardTitle } from "@/components/ui/card";
import { formatMinorExact,type QuoteComparison,type QuoteComparisonRow } from "@/lib/client-rfq/model";
import type { ClientRfqMessages } from "./messages";
import { compareQuotesAction,selectQuoteAction,type ActionState,type ComparisonState } from "./actions";

const compareIdle:ComparisonState={status:"idle"};
const actionIdle:ActionState={status:"idle"};

export function ComparisonPanel({locale,requestId,rfqId,messages,canManage,initialComparison,nowIso,compareKey,selectKeys}:{locale:"fr"|"ar";requestId:string;rfqId:string;messages:ClientRfqMessages;canManage:boolean;initialComparison:QuoteComparison|null;nowIso:string;compareKey:string;selectKeys:string[]}){
 const[state,action,pending]=useActionState(compareQuotesAction,compareIdle);
 const rows=state.status==="success"?state.rows:initialComparison?.rows??[];
 return <div className="space-y-5">
  {canManage?<form action={action}><input type="hidden" name="locale" value={locale}/><input type="hidden" name="rfqId" value={rfqId}/><input type="hidden" name="idempotencyKey" value={compareKey}/><Button disabled={pending} className="min-h-11 w-full sm:w-auto">{pending?messages.comparing:initialComparison?messages.refreshComparison:messages.compare}</Button></form>:<p role="status" className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">{messages.readOnly}</p>}
  {state.status==="error"?<p role="alert" className="text-destructive">{messages.actionError}</p>:null}
  {initialComparison&&state.status!=="success"?<p className="text-sm text-muted-foreground">{messages.snapshot}: <time dateTime={initialComparison.createdAt}>{new Intl.DateTimeFormat(locale==="ar"?"ar-MA":"fr-MA",{dateStyle:"medium",timeStyle:"short"}).format(new Date(initialComparison.createdAt))}</time> · <bdi>{initialComparison.normalizationVersion}</bdi></p>:null}
  {rows.length===0?<p className="rounded-xl border bg-card p-5 text-muted-foreground">{messages.noComparison}</p>:<div className="grid gap-4 lg:grid-cols-2" aria-live="polite">{rows.map((row,index)=><QuoteCard key={row.quoteVersionId} row={row} index={index} locale={locale} requestId={requestId} messages={messages} canManage={canManage} nowIso={nowIso} selectKey={selectKeys[index]??selectKeys[0]}/>)}</div>}
 </div>
}

function QuoteCard({row,index,locale,requestId,messages,canManage,nowIso,selectKey}:{row:QuoteComparisonRow;index:number;locale:"fr"|"ar";requestId:string;messages:ClientRfqMessages;canManage:boolean;nowIso:string;selectKey:string}){
 const[state,action,pending]=useActionState(selectQuoteAction,actionIdle);
 const expired=Date.parse(row.validUntil)<=Date.parse(nowIso);
 return <Card><CardHeader><CardTitle>{locale==="fr"?`Offre ${index+1}`:`العرض ${index+1}`} · {messages.rank} {row.priceRank}</CardTitle></CardHeader><CardContent className="space-y-4"><dl className="grid grid-cols-2 gap-3 text-sm"><dt>{messages.subtotal}</dt><dd className="text-end" dir="ltr">{formatMinorExact(row.subtotalMinor,row.currency,locale)}</dd><dt>{messages.tax}</dt><dd className="text-end" dir="ltr">{formatMinorExact(row.taxMinor,row.currency,locale)}</dd><dt className="font-semibold">{messages.total}</dt><dd className="text-end font-semibold" dir="ltr">{formatMinorExact(row.totalMinor,row.currency,locale)}</dd><dt>{messages.recurring}</dt><dd className="text-end" dir="ltr">{formatMinorExact(row.recurringSubtotalMinor,row.currency,locale)}</dd><dt>{messages.duration}</dt><dd>{row.durationDays} {messages.days}</dd><dt>{messages.deliverables}</dt><dd>{row.deliverablesCount}</dd><dt>{messages.validUntil}</dt><dd><time dateTime={row.validUntil}>{new Intl.DateTimeFormat(locale==="ar"?"ar-MA":"fr-MA",{dateStyle:"medium"}).format(new Date(row.validUntil))}</time></dd></dl>{canManage&&!expired?<form action={action}><input type="hidden" name="locale" value={locale}/><input type="hidden" name="requestId" value={requestId}/><input type="hidden" name="quoteId" value={row.quoteId}/><input type="hidden" name="quoteVersionId" value={row.quoteVersionId}/><input type="hidden" name="idempotencyKey" value={selectKey}/><Button disabled={pending} className="min-h-11 w-full">{messages.select}</Button></form>:expired?<p role="status" className="text-sm text-muted-foreground">{messages.expiredQuote}</p>:null}{state.status==="error"?<p role="alert" className="text-sm text-destructive">{messages.actionError}</p>:state.status==="success"?<p role="status" className="text-sm text-primary">{messages.selected}</p>:null}</CardContent></Card>
}
