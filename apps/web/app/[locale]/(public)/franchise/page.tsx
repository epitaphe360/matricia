import { CheckCircle2 } from "lucide-react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { localizedRouteMetadata } from "@/lib/seo/metadata";
import { NumberedCard, PageHero, SectionHeading } from "../_components/public-sections";
import { PublicCta, PublicShell } from "../_components/public-shell";
import { getPublicMessages } from "../messages";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const copy = getPublicMessages(locale).franchise;
  return localizedRouteMetadata(locale, "/franchise", copy.title, copy.description);
}

export default async function PublicFranchisePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getPublicMessages(locale);
  const copy = messages.franchise;
  return <PublicShell locale={locale} alternatePath="/franchise" messages={messages.common}>
    <main id="contenu-principal" tabIndex={-1}>
      <PageHero eyebrow={copy.eyebrow} title={copy.title} description={copy.description} />
      <section className="px-4 py-16 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading title={copy.roleTitle} description={copy.roleDescription}/><div className="mt-9 grid gap-5 md:grid-cols-3">{copy.roles.map((role, index) => <NumberedCard key={role.title} number={String(index + 1).padStart(2, "0")} title={role.title} description={role.description}/>)}</div></div></section>
      <section className="border-y bg-muted/40 px-4 py-16 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading title={copy.frameworkTitle}/><ul className="mt-8 grid gap-4 md:grid-cols-2">{copy.framework.map((item) => <li key={item} className="flex min-h-20 items-start gap-3 rounded-2xl border bg-card p-5 shadow-sm"><CheckCircle2 aria-hidden="true" className="mt-0.5 size-5 shrink-0 text-primary"/><span className="leading-7">{item}</span></li>)}</ul></div></section>
      <PublicCta locale={locale} title={copy.ctaTitle} description={copy.ctaDescription} messages={messages.common} secondaryHref={`/${locale}/services`} secondaryLabel={messages.common.explore}/>
    </main>
  </PublicShell>;
}
