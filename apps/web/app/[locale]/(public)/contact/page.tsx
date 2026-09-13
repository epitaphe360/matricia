import Link from "next/link";
import { notFound } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getContactMessages } from "./messages";

export default async function ContactPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getContactMessages(locale);

  return <main className="px-4 py-12 sm:px-6 sm:py-16">
    <div className="mx-auto max-w-5xl space-y-8">
      <header className="max-w-3xl">
        <p className="text-sm font-semibold uppercase tracking-[0.16em] text-primary">{messages.eyebrow}</p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight sm:text-5xl">{messages.title}</h1>
        <p className="mt-4 text-base leading-7 text-muted-foreground sm:text-lg">{messages.description}</p>
      </header>
      <section aria-label={messages.title} className="grid gap-5 md:grid-cols-2">
        <Card className="h-full"><CardHeader><CardTitle>{messages.serviceTitle}</CardTitle><CardDescription>{messages.serviceText}</CardDescription></CardHeader><CardContent><Link href={`/${locale}/services`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11 w-full sm:w-auto")}>{messages.serviceAction}</Link></CardContent></Card>
        <Card className="h-full"><CardHeader><CardTitle>{messages.accountTitle}</CardTitle><CardDescription>{messages.accountText}</CardDescription></CardHeader><CardContent><Link href={`/${locale}/connexion`} className={cn(buttonVariants(), "min-h-11 w-full sm:w-auto")}>{messages.accountAction}</Link></CardContent></Card>
      </section>
      <p className="rounded-xl border bg-muted/40 p-4 text-sm leading-6 text-muted-foreground">{messages.noForm}</p>
    </div>
  </main>;
}
