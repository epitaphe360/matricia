import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatExactScore } from "@/lib/diagnostics-opportunities/model";
import { createServerDiagnosticsRepository } from "@/lib/diagnostics-opportunities/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { CompleteForm } from "./complete-form";
import { messages } from "./messages";
import { IndicativeIntakes } from "./indicative-intakes";

export default async function Diagnostics({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await (await createServerDiagnosticsRepository()).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error") throw new Error("DIAGNOSTICS_UNAVAILABLE");
  const client = await getSupabaseServerClient();
  const intakeResult = await client.from("public_diagnostic_intakes").select("id,organization_id,priorities,created_at").order("created_at", { ascending: false }).limit(100);
  const organizationIds = [...new Set([...result.value.sessions.map((session) => session.organizationId), ...(intakeResult.data ?? []).map((intake) => intake.organization_id)])];
  const organizationResult = organizationIds.length ? await client.from("organizations").select("id,display_name").in("id", organizationIds) : { data: [], error: null };
  if (organizationResult.error) throw new Error("DIAGNOSTIC_ORGANIZATIONS_UNAVAILABLE");
  const names = new Map((organizationResult.data ?? []).map((organization) => [organization.id, organization.display_name]));
  const organizations = organizationIds.flatMap((id) => {
    const latest = result.value.sessions.find((session) => session.organizationId === id), name = names.get(id);
    return latest && name ? [{ id, name, latestAt: latest.submittedAt }] : [];
  });
  const m = messages(locale);
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}><div className="mx-auto max-w-6xl space-y-6">
    <header><h1 className="text-3xl font-semibold">{m.title}</h1><p className="mt-2 max-w-3xl text-muted-foreground">{m.intro}</p></header>
    <CompleteForm locale={locale} organizations={organizations} m={m} keyValue={randomUUID()} />
    <IndicativeIntakes locale={locale} failed={Boolean(intakeResult.error)} rows={(intakeResult.data ?? []).map((intake) => ({ id: intake.id, organizationId: intake.organization_id, organizationName: names.get(intake.organization_id) ?? (locale === "fr" ? "Organisation" : "المؤسسة"), priorities: intake.priorities, createdAt: intake.created_at }))} />
    <section aria-labelledby="runs"><h2 id="runs" className="mb-3 text-xl font-semibold">{m.runs}</h2>{!result.value.runs.length ? <p className="rounded-xl border bg-card p-5">{m.empty}</p> : <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{result.value.runs.map((run) => <Card key={run.id}><CardHeader><div className="flex justify-between gap-2"><CardTitle><span dir="ltr">{formatExactScore(run.score)}/100</span></CardTitle><Badge>{m.ratings[run.rating]}</Badge></div></CardHeader><CardContent><p>{new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short" }).format(new Date(run.completedAt))}</p><Link href={`/${locale}/client/diagnostics/${run.id}`} className="mt-3 inline-flex min-h-11 items-center font-medium underline">{m.view}</Link></CardContent></Card>)}</div>}</section>
  </div></main>;
}
