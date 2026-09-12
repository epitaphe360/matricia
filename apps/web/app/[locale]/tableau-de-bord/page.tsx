import Link from "next/link";
import { redirect, notFound } from "next/navigation";
import { Button, buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ModuleHub } from "@/components/module-hub";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { cn } from "@/lib/utils";
import { signOut } from "./actions";

export default async function DashboardPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ signout?: string }>;
}) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/connexion`);
  const { data: organizations, error: organizationsError } = await supabase.from("organizations").select("id,display_name,status").limit(10);
  const messages = getDictionary(locale).dashboard;
  const alternate = locale === "fr" ? "ar" : "fr";
  return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6"><div className="mx-auto max-w-5xl space-y-6">{query.signout === "failed" ? <p role="alert" className="rounded-lg border border-destructive/40 bg-destructive/10 p-3 text-sm text-destructive">{messages.signOutError}</p> : null}<header className="flex flex-wrap items-center justify-between gap-4"><div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1></div><div className="flex items-center gap-3"><Link href={`/${alternate}/tableau-de-bord`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2">{messages.language}</Link><form action={signOut}><input type="hidden" name="locale" value={locale} /><Button type="submit" variant="outline">{messages.signOut}</Button></form></div></header><div className="grid gap-5 md:grid-cols-2"><Card><CardHeader><CardTitle>{messages.session}</CardTitle><CardDescription>{messages.signedInAs}</CardDescription></CardHeader><CardContent className="space-y-4"><p className="break-all font-medium">{user.email ?? messages.unknownAccount}</p><Link href={`/${locale}/securite/sessions`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11 w-full sm:w-auto")}>{messages.sessionsAction}</Link></CardContent></Card><Card><CardHeader><CardTitle>{messages.organizationTitle}</CardTitle></CardHeader><CardContent className="space-y-4">{organizationsError ? <p role="alert" className="text-sm text-destructive">{messages.organizationError}</p> : organizations?.length ? <ul className="space-y-2">{organizations.map((organization) => <li key={organization.id} className="rounded-lg border bg-background p-3"><span className="font-medium">{organization.display_name}</span><span className="ms-2 text-xs text-muted-foreground">{messages.organizationStatus[organization.status as keyof typeof messages.organizationStatus] ?? messages.organizationStatus.unknown}</span></li>)}</ul> : <p className="text-muted-foreground">{messages.noOrganization}</p>}<Link href={`/${locale}/organisation`} className={cn(buttonVariants(), "min-h-11 w-full sm:w-auto")}>{messages.organizationAction}</Link></CardContent></Card></div><ModuleHub locale={locale} /></div></main>;
}
