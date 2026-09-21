import Link from"next/link";
import{Card,CardContent,CardDescription,CardHeader,CardTitle}from"@/modules/shared/ui/card";
import{adminV41Modules,type AdminV41Module,type AdminV41Overview}from"@/modules/admin/data/v41/model";
import type{getAdminV41Messages}from"./messages";

export function AdminV41OverviewPanel({overview,selected,locale,m}:{overview:AdminV41Overview;selected:AdminV41Module;locale:"fr"|"ar";m:ReturnType<typeof getAdminV41Messages>}){
 const current=overview.modules.find(item=>item.key===selected);
 if(!current)throw new Error("ADMIN_V41_MODULE_MISSING");
 const f=overview.financial_flows;
 return <div className="space-y-6">
  <nav aria-label={m.nav} className="flex gap-2 overflow-x-auto pb-2">{adminV41Modules.map(key=><Link key={key} href={`/${locale}/administration/v4-1/${key}`} aria-current={key===selected?"page":undefined} className="min-h-11 shrink-0 rounded-md border bg-background px-3 py-2 text-sm font-medium focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{m.modules[key]}</Link>)}</nav>
  <section aria-labelledby="selected-module"><Card><CardHeader><CardTitle id="selected-module">{m.modules[selected]}</CardTitle><CardDescription>{m.intro}</CardDescription></CardHeader><CardContent className="grid gap-4 sm:grid-cols-2"><div><p className="text-sm text-muted-foreground">{m.open}</p><p className="text-3xl font-semibold tabular-nums">{current.open}</p></div><div><p className="text-sm text-muted-foreground">{m.exceptions}</p><p className="text-3xl font-semibold tabular-nums">{current.exceptions}</p></div></CardContent></Card></section>
  <section aria-labelledby="financial-boundaries"><h2 id="financial-boundaries" className="mb-3 text-xl font-semibold">{m.flows}</h2><div className="grid gap-4 md:grid-cols-3"><Card><CardHeader><CardTitle>A</CardTitle><CardDescription>{m.flowA}</CardDescription></CardHeader><CardContent className="text-2xl font-semibold tabular-nums">{f.client_to_provider_declared}</CardContent></Card><Card><CardHeader><CardTitle>B</CardTitle><CardDescription>{m.flowB}</CardDescription></CardHeader><CardContent className="text-2xl font-semibold tabular-nums">{f.matricia_own_revenue}</CardContent></Card><Card><CardHeader><CardTitle>C</CardTitle><CardDescription>{m.flowC}</CardDescription></CardHeader><CardContent className="text-2xl font-semibold tabular-nums">{f.provider_commission_receipts}</CardContent></Card></div></section>
 </div>
}
