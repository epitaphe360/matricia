import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { AccountSecurityPanel } from "./account-security-panel";
import { getAccountSecurity } from "./actions";
import { getAccountSecurityMessages } from "./messages";

export default async function AccountSecurityPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await getAccountSecurity();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getAccountSecurityMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-5xl space-y-6">
        <header className="space-y-4">
          <nav aria-label={messages.navigation} className="flex flex-wrap items-center justify-between gap-3"><Link href={`/${locale}/tableau-de-bord`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link><Link href={`/${alternate}/securite/compte`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary">{messages.language}</Link></nav>
          <div><p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1><p className="mt-3 max-w-3xl text-muted-foreground">{messages.description}</p></div>
        </header>
        {result.status === "error" ? <Alert variant="destructive"><AlertTitle>{messages.unavailableTitle}</AlertTitle><AlertDescription><p>{messages.unavailableDescription}</p><Link href={`/${locale}/securite/compte`} className={cn(buttonVariants({ variant: "outline" }), "mt-3 min-h-11")}>{messages.retry}</Link></AlertDescription></Alert> : <AccountSecurityPanel locale={locale} security={result} messages={messages} />}
      </div>
    </main>
  );
}
