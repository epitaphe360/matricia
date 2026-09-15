import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { z } from "zod";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button, buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ModuleHub } from "@/components/module-hub";
import { dashboardHomeCopy, resolveOrganizationContext } from "@/components/module-hub-copy";
import { loadUserActionCenter } from "@/lib/action-center/repository";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { cn } from "@/lib/utils";
import { signOut } from "./actions";

const membershipRows = z.array(z.object({ id: z.string().uuid(), organization_id: z.string().uuid(), organizations: z.object({ display_name: z.string().min(1), status: z.string() }) }));

export default async function DashboardPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ signout?: string; organizationId?: string }> }) {
  const { locale } = await params, query = await searchParams;
  if (!isLocale(locale)) notFound();
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/connexion`);
  const [membershipsQuery, actionCenter] = await Promise.all([supabase.from("organization_memberships").select("id,organization_id,organizations!inner(display_name,status)").eq("user_id", user.id).eq("status", "ACTIVE").limit(25), loadUserActionCenter(locale)]);
  const memberships = membershipRows.safeParse(membershipsQuery.data), organizationsUnavailable = Boolean(membershipsQuery.error) || !memberships.success;
  const requestedOrganizationId = typeof query.organizationId === "string" ? query.organizationId : null;
  const context = resolveOrganizationContext(memberships.success ? memberships.data.map((membership) => ({ membershipId: membership.id, organizationId: membership.organization_id })) : [], requestedOrganizationId);
  const selectedMembership = memberships.success ? memberships.data.find((membership) => membership.id === context.selected?.membershipId) ?? null : null;
  const m = dashboardHomeCopy[locale], alternate = locale === "fr" ? "ar" : "fr";
  const priorities = actionCenter.status === "success" && selectedMembership ? actionCenter.value.items.filter((item) => item.organizationId === selectedMembership.organization_id || item.organizationId === null).slice(0, 3) : [];
  const selectedQuery = context.selected ? `?organizationId=${encodeURIComponent(context.selected.organizationId)}` : "";

  return <main dir={locale === "ar" ? "rtl" : "ltr"} className="min-h-dvh bg-[#F7F9FC] px-4 py-6 text-[#14213D] sm:px-6 sm:py-8"><div className="mx-auto max-w-6xl space-y-6">
    {query.signout === "failed" ? <Alert variant="destructive"><AlertDescription>{m.signOutError}</AlertDescription></Alert> : null}
    {context.rejected ? <Alert variant="destructive"><AlertDescription>{m.contextRejected}</AlertDescription></Alert> : null}
    <header className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7"><div className="flex flex-wrap items-start justify-between gap-5"><div className="max-w-3xl"><p className="text-xs font-semibold uppercase tracking-[.18em] text-[#1D4ED8]">{m.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight sm:text-4xl">{m.title}</h1><p className="mt-3 leading-7 text-slate-600">{m.intro}</p>{selectedMembership ? <p className="mt-3 font-semibold text-[#0B1739]">{m.selected} : {selectedMembership.organizations.display_name}</p> : null}</div><div className="flex flex-wrap gap-2"><Link href={`/${alternate}/tableau-de-bord${selectedQuery}`} hrefLang={alternate} lang={alternate} className="min-h-11 rounded-md px-3 py-2.5 text-sm font-medium text-[#1D4ED8] focus-visible:outline focus-visible:outline-2">{m.language}</Link><form action={signOut}><input type="hidden" name="locale" value={locale}/><Button type="submit" variant="outline" className="min-h-11">{m.signOut}</Button></form></div></div></header>
    <section aria-labelledby="dashboard-priorities" className="grid gap-5 lg:grid-cols-[1.35fr_.65fr]">
      <Card><CardHeader><CardTitle id="dashboard-priorities">{m.actionsTitle}</CardTitle><CardDescription>{m.actionsDescription}</CardDescription></CardHeader><CardContent className="space-y-4">{actionCenter.status === "error" ? <p role="alert" className="text-sm text-destructive">{m.actionsError}</p> : priorities.length === 0 ? <p role="status" className="text-sm text-muted-foreground">{m.actionsEmpty}</p> : <ul className="space-y-3">{priorities.map((item) => <li key={item.id}><Link href={`${item.href}${item.href.includes("?") ? "&" : "?"}organizationId=${encodeURIComponent(context.selected!.organizationId)}`} className="block rounded-xl border border-slate-200 p-4 hover:border-blue-300 hover:bg-blue-50/40 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><div className="flex flex-wrap justify-between gap-2"><span className="font-semibold">{item.title}</span><Badge variant={item.priority === "CRITICAL" || item.priority === "HIGH" ? "destructive" : "secondary"}>{m.priority[item.priority]}</Badge></div>{item.organizationName ? <span className="mt-2 block text-sm text-slate-600">{item.organizationName}</span> : null}</Link></li>)}</ul>}<Link href={`/${locale}/actions${selectedQuery}`} className={cn(buttonVariants(), "min-h-11 w-full sm:w-auto")}>{m.actionsCta}</Link></CardContent></Card>
      <Card><CardHeader><CardTitle>{m.accountTitle}</CardTitle><CardDescription>{m.signedInAs}</CardDescription></CardHeader><CardContent className="space-y-4"><p className="break-all font-medium" dir="ltr">{user.email ?? "—"}</p><Link href={`/${locale}/securite/sessions`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11 w-full")}>{m.sessionsCta}</Link></CardContent></Card>
    </section>
    <Card><CardHeader><CardTitle>{m.organizationsTitle}</CardTitle><CardDescription>{m.organizationsDescription}</CardDescription></CardHeader><CardContent className="space-y-4">{organizationsUnavailable ? <p role="alert" className="text-sm text-destructive">{m.organizationError}</p> : memberships.data.length === 0 ? <p role="status" className="text-sm text-muted-foreground">{m.organizationEmpty}</p> : <ul className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{memberships.data.map((membership) => { const selected = membership.id === context.selected?.membershipId; return <li key={membership.id} className={cn("rounded-xl border p-4", selected ? "border-blue-500 bg-blue-50/50" : "border-slate-200")}><span className="block font-semibold">{membership.organizations.display_name}</span><span className="mt-1 block text-sm text-slate-600">{m.status[membership.organizations.status as keyof typeof m.status] ?? m.status.unknown}</span>{selected ? <Badge className="mt-3">{m.selected}</Badge> : <Link href={`/${locale}/tableau-de-bord?organizationId=${encodeURIComponent(membership.organization_id)}`} className={cn(buttonVariants({ variant: "outline" }), "mt-3 min-h-11 w-full")}>{m.select} {membership.organizations.display_name}</Link>}</li>; })}</ul>}<p className="text-sm text-slate-600">{m.contextLimit}</p><Link href={`/${locale}/organisation${selectedQuery}`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11 w-full sm:w-auto")}>{m.organizationCta}</Link></CardContent></Card>
    <ModuleHub locale={locale} selectedOrganizationId={context.selected?.organizationId ?? null}/>
  </div></main>;
}
