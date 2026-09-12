import { CheckCircle2, Layers3 } from "lucide-react";
import { notFound } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { getStaticPublicCatalogue } from "@/lib/public-catalogue/static-projection";
import { PublicCta, PublicShell } from "../_components/public-shell";
import { NumberedCard, PageHero, SectionHeading } from "../_components/public-sections";
import { getPublicMessages } from "../messages";

export default async function PublicServicesPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getPublicMessages(locale);
  const catalogue = getStaticPublicCatalogue(locale);

  return <PublicShell locale={locale} alternatePath="/services" messages={messages.common}>
    <main id="contenu-principal">
      <PageHero eyebrow={messages.services.eyebrow} title={messages.services.title} description={messages.services.description}>
        <dl className="mt-9 flex flex-wrap gap-4"><div className="rounded-xl border border-white/15 bg-white/10 px-5 py-4"><dt className="text-sm text-white/65">{messages.home.metrics[0].label}</dt><dd className="mt-1 text-3xl font-bold" dir="ltr">{catalogue.libraryCount}</dd></div><div className="rounded-xl border border-white/15 bg-white/10 px-5 py-4"><dt className="text-sm text-white/65">{messages.home.metrics[1].label}</dt><dd className="mt-1 text-3xl font-bold" dir="ltr">{catalogue.serviceCount}</dd></div></dl>
      </PageHero>

      <section className="px-4 py-16 sm:px-6 sm:py-24 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading title={messages.services.librariesTitle} description={messages.services.librariesDescription} /><ul className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{catalogue.libraries.map(library => <li key={library.code} className="flex min-h-32 items-start gap-4 rounded-2xl border bg-card p-5 shadow-sm"><span className="grid size-11 shrink-0 place-items-center rounded-xl bg-accent font-bold text-accent-foreground" dir="ltr">{library.code.length > 4 ? <Layers3 aria-hidden="true" className="size-5" /> : library.code}</span><div><h3 className="font-semibold leading-6">{library.name}</h3><p className="mt-2 text-sm text-muted-foreground">{messages.services.serviceCountLabel(library.serviceCount)}</p></div></li>)}</ul></div></section>

      <section className="border-y bg-muted/40 px-4 py-16 sm:px-6 sm:py-24 lg:px-8"><div className="mx-auto max-w-7xl"><div className="grid items-start gap-10 lg:grid-cols-[0.75fr_1.25fr]"><div><span className="grid size-12 place-items-center rounded-2xl bg-primary text-primary-foreground"><CheckCircle2 aria-hidden="true" /></span><SectionHeading title={messages.services.methodTitle} description={messages.services.methodDescription} /></div><ol className="grid gap-5 sm:grid-cols-3">{messages.services.method.map((item, index) => <li key={item.title}><NumberedCard number={String(index + 1).padStart(2, "0")} title={item.title} description={item.description} /></li>)}</ol></div></div></section>

      <PublicCta locale={locale} title={messages.services.ctaTitle} description={messages.services.ctaDescription} messages={messages.common} />
    </main>
  </PublicShell>;
}
