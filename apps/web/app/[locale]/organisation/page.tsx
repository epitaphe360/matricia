import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { OrganizationForm } from "./organization-form";

export default async function OrganizationPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/connexion`);

  const messages = getDictionary(locale).organization;
  const alternate = locale === "fr" ? "ar" : "fr";
  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6 sm:py-12">
      <div className="mx-auto w-full max-w-2xl space-y-5">
        <nav aria-label={messages.backToDashboard} className="flex flex-wrap items-center justify-between gap-3">
          <Button asChild variant="ghost"><Link href={`/${locale}/tableau-de-bord`}>{messages.backToDashboard}</Link></Button>
          <Link href={`/${alternate}/organisation`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link>
        </nav>
        <Card className="shadow-xl">
          <CardHeader className="space-y-3">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
            <CardTitle className="text-2xl sm:text-3xl">{messages.title}</CardTitle>
            <CardDescription className="leading-6">{messages.description}</CardDescription>
          </CardHeader>
          <CardContent><OrganizationForm locale={locale} idempotencyKey={randomUUID()} /></CardContent>
        </Card>
      </div>
    </main>
  );
}
