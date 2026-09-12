import{randomUUID}from"node:crypto";
import{notFound,redirect}from"next/navigation";
import{Badge}from"@/components/ui/badge";
import{Card,CardContent,CardHeader,CardTitle}from"@/components/ui/card";
import{isLocale}from"@/lib/i18n/locale";
import{formatMinorExact}from"@/lib/solution-insights/model";
import{createServerSolutionInsightsRepository}from"@/lib/solution-insights/server-repository";
import{DecisionForm}from"./decision-form";
import{messages}from"./messages";

function text(value:unknown,locale:"fr"|"ar"){if(typeof value==="string")return value;if(value&&typeof value==="object"){const v=value as Record<string,unknown>,localized=v[locale]??v.label;if(typeof localized==="string")return localized}return "-"}
export default async function SolutionsPage({params}:{params:Promise<{locale:string}>}){
 const{locale}=await params;if(!isLocale(locale))notFound();
 const result=await(await createServerSolutionInsightsRepository()).list();
 if(result.status==="error"&&result.reason==="UNAUTHENTICATED")redirect(`/${locale}/connexion`);
 if(result.status==="error"&&result.reason==="FORBIDDEN")return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6"><section role="alert" className="mx-auto max-w-3xl rounded-2xl border bg-card p-6"><h1 className="text-2xl font-semibold">{locale==="ar"?"\u0627\u0644\u0648\u0635\u0648\u0644 \u063a\u064a\u0631 \u0645\u0633\u0645\u0648\u062d":"Acces non autorise"}</h1></section></main>;
 if(result.status==="error")throw new Error("SOLUTION_INSIGHTS_UNAVAILABLE");
 const m=messages(locale);
 return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-6xl space-y-8"><header><h1 className="text-3xl font-semibold">{m.title}</h1><p className="mt-2 max-w-3xl text-muted-foreground">{m.intro}</p></header><section className="space-y-5" aria-label={m.title}>{!result.value.sets.length?<p className="rounded-xl border bg-card p-5">{m.empty}</p>:result.value.sets.map(set=><Card key={set.id}><CardHeader><div className="flex flex-wrap items-center justify-between gap-2"><CardTitle>{m.rationale}</CardTitle><Badge>v{set.version}</Badge></div><p>{locale==="ar"?set.rationaleAr:set.rationaleFr}</p></CardHeader><CardContent className="grid gap-4 lg:grid-cols-3">{set.options.map(option=><article key={option.id} className="rounded-xl border p-4"><h2 className="text-lg font-semibold">{m.levels[option.level]}</h2><dl className="mt-3 space-y-2"><div><dt className="font-medium">{m.expected}</dt><dd>{(option.expectedScoreBps/100).toFixed(2)}%</dd></div><div><dt className="font-medium">{m.amount}</dt><dd dir="ltr">{option.estimatedAmountMinor&&option.currency?formatMinorExact(option.estimatedAmountMinor,option.currency,locale):"-"}</dd></div></dl>{option.benefits.length>0&&<ul className="mt-3 list-disc ps-5">{option.benefits.map((item,index)=><li key={index}>{text(item,locale)}</li>)}</ul>}<DecisionForm locale={locale} solutionSetId={set.id} level={option.level} idempotencyKey={randomUUID()} m={m}/></article>)}</CardContent></Card>)}</section><section aria-labelledby="benchmarks"><h2 id="benchmarks" className="text-2xl font-semibold">{m.benchmarks}</h2>{!result.value.benchmarks.length?<p className="mt-3 rounded-xl border bg-card p-5">{m.noBenchmarks}</p>:<div className="mt-3 grid gap-3 sm:grid-cols-2">{result.value.benchmarks.map(item=><Card key={item.id}><CardContent className="pt-6"><h3 className="font-semibold">{item.metricCode}</h3><p>{item.segmentKey}</p><p>{m.period}: {item.periodStart} - {item.periodEnd}</p><p>{m.group}: {item.groupSizeBand}</p><p>{m.mean}: {item.roundedMean}</p></CardContent></Card>)}</div>}</section></div></main>
}
