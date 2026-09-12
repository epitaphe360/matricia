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
  const copy = getPublicMessages(locale).about;
  return localizedRouteMetadata(locale, "/a-propos", copy.title, copy.description);
}

export default async function PublicAboutPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getPublicMessages(locale);
  const copy = messages.about;
  return <PublicShell locale={locale} alternatePath="/a-propos" messages={messages.common}>
    <main id="contenu-principal" tabIndex={-1}>
      <PageHero eyebrow={copy.eyebrow} title={copy.title} description={copy.description}/>
      <section className="px-4 py-16 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading title={copy.missionTitle} description={copy.missionDescription}/></div></section>
      <section className="border-y bg-muted/40 px-4 py-16 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading title={copy.principlesTitle}/><div className="mt-9 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">{copy.principles.map((principle, index) => <NumberedCard key={principle.title} number={String(index + 1).padStart(2, "0")} title={principle.title} description={principle.description}/>)}</div></div></section>
      <section className="px-4 py-16 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-7xl rounded-3xl border bg-card p-6 shadow-sm sm:p-10"><SectionHeading title={copy.approachTitle} description={copy.approachDescription}/></div></section>
      <PublicCta locale={locale} title={copy.ctaTitle} description={copy.ctaDescription} messages={messages.common} secondaryHref={`/${locale}/services`} secondaryLabel={messages.common.explore}/>
    </main>
  </PublicShell>;
}
