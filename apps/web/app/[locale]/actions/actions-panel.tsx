import Link from "next/link";
import { Badge } from "@/modules/shared/ui/badge";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { UserActionCenter } from "@/modules/shared/lib/action-center/model";
import type { ActionCenterMessages } from "./messages";

export function ActionsPanel({ center, locale, m }: { center: UserActionCenter; locale: Locale; m: ActionCenterMessages }) {
  const date = new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short" });
  const mandatory = center.items.filter((item) => item.mandatory).length;
  const human = center.items.filter((item) => item.requiresHumanReview).length;
  return <div className="space-y-6">
    <section aria-label={m.all} className="grid gap-3 sm:grid-cols-3">
      {[[m.all, center.items.length], [m.mandatory, mandatory], [m.human, human]].map(([label, value]) => <div key={String(label)} className="rounded-2xl border bg-card p-5 shadow-sm"><p className="text-sm text-muted-foreground">{label}</p><p className="mt-2 text-3xl font-semibold" dir="ltr">{value}</p></div>)}
    </section>
    <p role="note" className="rounded-2xl border border-amber-300 bg-amber-50 p-4 text-sm leading-6 text-amber-950">{m.noAutomaticSanction}</p>
    {center.degradedSources.includes("ADMIN") ? <p role="status" className="rounded-xl border p-4 text-sm">{m.sourceWarning}</p> : null}
    <section aria-labelledby="action-list-title" className="space-y-3"><h2 id="action-list-title" className="text-2xl font-semibold">{m.all}</h2>
      {center.items.length === 0 ? <p role="status" className="rounded-2xl border bg-card p-6 text-muted-foreground">{m.empty}</p> : <ol className="space-y-3">{center.items.map((item) => <li key={item.id}><article className="min-w-0 rounded-2xl border bg-card p-4 shadow-sm sm:p-5"><div className="flex flex-wrap items-start justify-between gap-3"><div className="min-w-0"><p className="text-xs font-semibold uppercase tracking-[.14em] text-primary">{m.kinds[item.kind]}</p><h3 className="mt-1 break-words text-lg font-semibold">{item.title}</h3></div><div className="flex flex-wrap gap-2">{item.mandatory ? <Badge variant="destructive">{m.mandatoryBadge}</Badge> : null}{item.requiresHumanReview ? <Badge variant="outline">{m.humanBadge}</Badge> : null}<Badge variant={item.priority === "CRITICAL" ? "destructive" : "secondary"}>{item.priority}</Badge></div></div><p className="mt-3 break-words text-sm leading-6 text-muted-foreground">{item.detail}</p>{item.organizationName ? <p className="mt-2 text-sm"><span className="text-muted-foreground">{m.organization} :</span> {item.organizationName}</p> : null}<div className="mt-4 flex flex-wrap items-center justify-between gap-3">{item.dueAt ? <p className="text-sm"><span className="text-muted-foreground">{m.due} :</span> <time dateTime={item.dueAt}>{date.format(new Date(item.dueAt))}</time></p> : <time className="text-sm text-muted-foreground" dateTime={item.occurredAt}>{date.format(new Date(item.occurredAt))}</time>}<Link href={item.href} className="min-h-11 rounded-md px-3 py-2 font-medium text-primary underline-offset-4 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{m.open}</Link></div></article></li>)}</ol>}
    </section>
  </div>;
}

