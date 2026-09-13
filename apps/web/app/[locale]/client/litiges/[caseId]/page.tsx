import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound,redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card,CardContent,CardHeader,CardTitle } from "@/components/ui/card";
import { formatMinorAmount } from "@/lib/disputes/model";
import { createServerDisputesRepository } from "@/lib/disputes/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { ActionPanel } from "../action-panel";
import { getDisputeMessages } from "../messages";

function date(value:string|null,locale:"fr"|"ar"){return value?new Intl.DateTimeFormat(locale==="ar"?"ar-MA":"fr-MA",{dateStyle:"medium",timeStyle:"short"}).format(new Date(value)):"—";}

export default async function DisputePage({params}:{params:Promise<{locale:string;caseId:string}>}){
 const{locale,caseId}=await params;if(!isLocale(locale))notFound();const result=await(await createServerDisputesRepository()).detail(caseId);if(result.status==="error"&&result.reason==="UNAUTHENTICATED")redirect(`/${locale}/connexion`);if(result.status==="error"||!result.value)notFound();
 const d=result.value,m=getDisputeMessages(locale),keys=Object.fromEntries(["respond","appeal","decide","propose","approve","activate"].map(x=>[x,randomUUID()]));
 return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-6xl space-y-6">
  <Link href={`/${locale}/client/litiges`} className={cn(buttonVariants({variant:"outline"}),"min-h-11")}>{m.back}</Link>
  <Card><CardHeader><div className="flex flex-wrap justify-between gap-3"><CardTitle>{d.obligationKey}</CardTitle><Badge>{m.statuses[d.status]}</Badge></div></CardHeader><CardContent className="space-y-3"><p className="whitespace-pre-wrap leading-7">{d.description}</p><dl className="grid gap-3 text-sm sm:grid-cols-2 lg:grid-cols-4"><div><dt className="text-muted-foreground">{m.policy}</dt><dd>{d.policyVersion}</dd></div><div><dt className="text-muted-foreground">{m.deadline}</dt><dd>{date(d.responseDueAt,locale)}</dd></div><div><dt className="text-muted-foreground">{m.reviewDeadline}</dt><dd>{date(d.reviewDueAt,locale)}</dd></div><div><dt className="text-muted-foreground">{m.appealDeadline}</dt><dd>{date(d.appealDueAt,locale)}</dd></div><div><dt className="text-muted-foreground">{m.mission}</dt><dd dir="ltr">{d.missionId}</dd></div></dl></CardContent></Card>
  <section aria-labelledby="evidence-title"><h2 id="evidence-title" className="mb-3 text-xl font-semibold">{m.evidence}</h2><div className="grid gap-3 md:grid-cols-2">{d.evidence.map(x=><article key={x.id} className="rounded-xl border bg-card p-4"><div className="flex justify-between gap-2"><strong>{x.type}</strong><Badge variant="outline">{m.visibilities[x.visibility]}</Badge></div><p className="mt-2 whitespace-pre-wrap">{x.statement??x.url}</p><p className="mt-2 text-xs text-muted-foreground">{date(x.createdAt,locale)}</p><code className="mt-1 block break-all text-xs" dir="ltr">{x.hash}</code></article>)}</div></section>
  {d.response?<section aria-labelledby="response-title"><h2 id="response-title" className="mb-3 text-xl font-semibold">{m.responseTitle}</h2><Card><CardContent className="space-y-2 pt-6"><Badge variant="outline">{m.responseTypes[d.response.type]}</Badge><p className="whitespace-pre-wrap">{d.response.statement}</p><p className="text-sm text-muted-foreground">{m.responseDate} {date(d.response.submittedAt,locale)}</p></CardContent></Card></section>:null}
  {d.decisions.length>0?<section aria-labelledby="decisions-title"><h2 id="decisions-title" className="mb-3 text-xl font-semibold">{m.decisions}</h2><div className="space-y-3">{d.decisions.map(item=><Card key={item.id}><CardHeader><div className="flex flex-wrap items-center justify-between gap-2"><CardTitle>{m.decisionNumber}{item.number}</CardTitle><Badge>{m.outcomes[item.outcome]}</Badge></div></CardHeader><CardContent className="space-y-2"><p className="whitespace-pre-wrap">{item.reason}</p><p className="text-sm text-muted-foreground">{m.ruleVersion}: {item.ruleVersion} · {m.decisionDate} {date(item.decidedAt,locale)}</p><p className="break-all text-xs text-muted-foreground" dir="ltr">{m.evidenceIds}: {item.evidenceIds.join(", ")}</p></CardContent></Card>)}</div></section>:null}
  {d.appeal?<section aria-labelledby="appeal-title"><h2 id="appeal-title" className="mb-3 text-xl font-semibold">{m.appealTitle}</h2><Card><CardContent className="space-y-2 pt-6"><p className="whitespace-pre-wrap">{d.appeal.grounds}</p><p className="text-sm text-muted-foreground">{m.appealDate} {date(d.appeal.submittedAt,locale)}</p></CardContent></Card></section>:null}
  <section aria-labelledby="timeline-title"><h2 id="timeline-title" className="mb-3 text-xl font-semibold">{m.timeline}</h2><ol className="space-y-2 border-s ps-5">{d.events.map(x=><li key={x.id}><strong>{x.type}</strong><span className="block text-sm text-muted-foreground">{x.from??"—"} → {x.to} · {date(x.createdAt,locale)}</span></li>)}</ol></section>
  {d.reassignment?<Card><CardHeader><CardTitle>{m.reassignment} {d.reassignment.key}</CardTitle></CardHeader><CardContent className="grid gap-2 text-sm sm:grid-cols-3"><p>{m.status}: <strong>{d.reassignment.status}</strong></p><p>{m.originalCost}: <strong dir="ltr">{formatMinorAmount(d.reassignment.originalCostMinor,d.reassignment.currency,locale)}</strong></p><p>{m.costDelta}: <strong dir="ltr">{formatMinorAmount(d.reassignment.costDeltaMinor??"0",d.reassignment.currency,locale)}</strong></p></CardContent></Card>:null}
  <section aria-labelledby="actions-title"><h2 id="actions-title" className="mb-3 text-xl font-semibold">{m.actions}</h2><ActionPanel locale={locale} d={d} m={m} keys={keys}/></section>
 </div></main>;
}
