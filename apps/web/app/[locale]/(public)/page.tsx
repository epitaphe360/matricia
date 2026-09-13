import { ArrowRight, Building2, Network, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { PUBLIC_CATALOGUE_TOTALS } from "@/lib/public-catalogue/static-projection";
import { cn } from "@/lib/utils";
import { PublicCta, PublicShell } from "./_components/public-shell";
import { NumberedCard, SectionHeading } from "./_components/public-sections";
import { getPublicMessages } from "./messages";

const audienceIcons = [Building2, ShieldCheck, Network] as const;

export default async function PublicHomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getPublicMessages(locale);

  return <PublicShell locale={locale} alternatePath="" messages={messages.common}>
    <main id="contenu-principal">
      <section className="relative isolate overflow-hidden bg-primary px-4 py-16 text-primary-foreground sm:px-6 sm:py-24 lg:px-8">
        <div aria-hidden="true" className="absolute -end-24 -top-28 size-80 rounded-full bg-white/10 blur-3xl" />
        <div aria-hidden="true" className="absolute -bottom-36 start-1/3 size-80 rounded-full bg-accent/30 blur-3xl" />
        <div className="relative mx-auto grid max-w-7xl items-end gap-12 lg:grid-cols-[1.4fr_0.6fr]">
          <div><p className="text-sm font-semibold uppercase tracking-[0.18em] text-white/70">{messages.home.eyebrow}</p><h1 className="mt-5 max-w-4xl text-4xl font-semibold tracking-tight text-balance sm:text-5xl lg:text-6xl">{messages.home.title}</h1><p className="mt-6 max-w-3xl text-lg leading-8 text-white/75 sm:text-xl">{messages.home.description}</p><div className="mt-8 flex flex-col gap-3 sm:flex-row"><Link href={`/${locale}/services`} className={cn(buttonVariants({ size: "lg" }), "min-h-12 bg-white text-primary hover:bg-white/90")}>{messages.common.explore}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180" /></Link><Link href={`/${locale}/connexion`} className={cn(buttonVariants({ variant: "outline", size: "lg" }), "min-h-12 border-white/35 bg-transparent text-white hover:bg-white/10 hover:text-white")}>{messages.common.signIn}</Link></div></div>
          <aside aria-label={messages.home.proofLabel} className="rounded-2xl border border-white/15 bg-white/10 p-5 shadow-2xl backdrop-blur sm:p-6"><p className="text-sm font-semibold text-white/70">{messages.home.proofLabel}</p><dl className="mt-5 grid grid-cols-2 gap-4">{messages.home.metrics.map((metric, index) => <div key={metric.value} className="rounded-xl bg-white/10 p-4"><dt className="mt-2 text-sm leading-5 text-white/70">{metric.label}</dt><dd className="text-3xl font-bold" dir="ltr">{index === 0 ? PUBLIC_CATALOGUE_TOTALS.libraryCount : PUBLIC_CATALOGUE_TOTALS.serviceCount}</dd></div>)}</dl></aside>
        </div>
      </section>

      <section className="px-4 py-16 sm:px-6 sm:py-24 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading eyebrow={messages.home.valueEyebrow} title={messages.home.valueTitle} description={messages.home.valueDescription} /><ol className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">{messages.home.values.map((value, index) => <li key={value.title}><NumberedCard number={String(index + 1).padStart(2, "0")} title={value.title} description={value.description} /></li>)}</ol></div></section>

      <section className="border-y bg-muted/40 px-4 py-16 sm:px-6 sm:py-24 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading eyebrow={messages.home.audiencesEyebrow} title={messages.home.audiencesTitle} /><div className="mt-10 grid gap-5 md:grid-cols-3">{messages.home.audiences.map((audience, index) => { const Icon = audienceIcons[index]; return <article key={audience.title} className="rounded-2xl border bg-card p-6 shadow-sm"><span className="grid size-11 place-items-center rounded-xl bg-accent text-accent-foreground"><Icon aria-hidden="true" className="size-5" /></span><h3 className="mt-5 text-xl font-semibold">{audience.title}</h3><p className="mt-3 leading-7 text-muted-foreground">{audience.description}</p></article>; })}</div></div></section>

      <PublicCta locale={locale} title={messages.home.ctaTitle} description={messages.home.ctaDescription} messages={messages.common} secondaryHref={`/${locale}/contact`} secondaryLabel={messages.common.contact} />
    </main>
  </PublicShell>;
}
