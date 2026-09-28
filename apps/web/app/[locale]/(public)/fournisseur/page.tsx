import { CheckCircle2, ClipboardList, FolderCheck, ListChecks, ShieldCheck, UserRound } from "lucide-react";
import type { Metadata } from "next";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { getPublicProviderTaxonomy } from "@/modules/public/data/provider-intent/model";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { ProviderTaxonomySelector } from "./provider-taxonomy-selector";
import Link from "next/link";

const trustTones = ["violet", "coral", "mint"] as const;
const qualifyIcons = [ClipboardList, ListChecks, UserRound, FolderCheck, ShieldCheck] as const;

export async function generateMetadata({ params }: { params: Promise<{ locale: Locale }> }): Promise<Metadata> {
  const { locale } = await params;
  const copy = getPublicJourneyCopy(locale).provider;
  return localizedRouteMetadata(locale, "/fournisseur", copy.title, copy.intro);
}

export default async function ProviderEntry({ params }: { params: Promise<{ locale: Locale }> }) {
  const { locale } = await params;
  const copy = getPublicJourneyCopy(locale).provider;
  const taxonomy = getPublicProviderTaxonomy(locale);
  const destination = `/${locale}/sous-traitant/qualification`;
  const existingHref = `/${locale}/connexion?next=${encodeURIComponent(destination)}`;

  return (
    <main id="contenu-principal" className="public-page pb-16">
      <section className="public-hero-split">
        <div>
          <p className="journey-eyebrow is-coral">{copy.eyebrow}</p>
          <h1>{copy.title}</h1>
          <p className="public-lead mt-4">{copy.intro}</p>
          <div className="journey-actions">
            <a className="journey-primary" href="#inscription-guidee">{copy.begin}</a>
            <Link className="journey-secondary" href={existingHref}>{copy.existing}</Link>
          </div>
          <ul className="journey-trust">
            {copy.trust.map((item, index) => (
              <li key={item} data-tone={trustTones[index] ?? "mint"}>
                <span className="journey-trust-icon" aria-hidden="true"><CheckCircle2 size={16} /></span>
                {item}
              </li>
            ))}
          </ul>
        </div>
        <ul className="provider-profile-mosaic" aria-label={locale === "ar" ? "مجالات المهنيين" : "Domaines des professionnels"}>
          {taxonomy.libraries.map((library) => <li key={library.code}>{library.name}</li>)}
        </ul>
      </section>

      <section id="inscription-guidee" className="public-wrap">
        <p className="journey-eyebrow is-coral">{copy.guidedEyebrow}</p>
        <h2 className="mt-2 max-w-3xl text-[clamp(1.55rem,2.6vw,2.05rem)] font-semibold tracking-[-0.03em] text-[var(--jp-navy)]">{copy.guidedTitle}</h2>
        <p className="journey-login-note mt-3">{copy.note}</p>
        <div className="public-contact-board mt-6">
          <div className="public-card mt-0 max-w-none">
            <ProviderTaxonomySelector locale={locale} libraries={taxonomy.libraries} activityLabel={copy.activity} activityExample={copy.example} />
          </div>
          <aside className="public-card provider-why-card">
            <h2>{copy.whyTitle}</h2>
            <p className="public-muted mt-2">{copy.whyText}</p>
            <ul className="mt-4 space-y-2 text-sm text-slate-700">
              {copy.whyItems.map((item) => (
                <li key={item} className="flex items-start gap-2">
                  <CheckCircle2 aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-[var(--mat-mint-ink)]" />
                  {item}
                </li>
              ))}
            </ul>
          </aside>
        </div>
      </section>

      <section className="public-wrap mt-12">
        <p className="journey-eyebrow is-coral">{copy.qualifyEyebrow}</p>
        <h2 className="mt-2">{copy.qualifyTitle}</h2>
        <p className="public-muted mt-2 max-w-3xl">{copy.qualifyLead}</p>
        <div className="public-contact-board mt-6">
          <ol className="journey-need-stages provider-qualify-stages" aria-label={copy.qualifyTitle}>
            {copy.qualifySteps.map(([title, text], index) => {
              const Icon = qualifyIcons[index] ?? ShieldCheck;
              return (
                <li key={title} data-state={index === 0 ? "current" : undefined}>
                  <span aria-hidden="true"><Icon size={16} /></span>
                  <strong>{title}</strong>
                  <em>{text}</em>
                </li>
              );
            })}
          </ol>
          <aside className="public-card provider-criteria-card">
            <h3>{copy.criteriaTitle}</h3>
            <ul className="mt-4 space-y-2 text-sm text-slate-700">
              {copy.criteriaItems.map((item) => (
                <li key={item} className="flex items-start gap-2">
                  <CheckCircle2 aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-[#8a6a3d]" />
                  {item}
                </li>
              ))}
            </ul>
          </aside>
        </div>
      </section>

      <section className="public-wrap journey-cta-band mt-10">
        <div>
          <h2>{copy.ctaTitle}</h2>
          <p>{copy.ctaText}</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <a className="journey-primary" href="#inscription-guidee">{copy.begin}</a>
          <Link className="journey-secondary" href={existingHref}>{copy.existing}</Link>
          <p className="provider-cta-tagline ms-auto">{copy.ctaTagline}</p>
        </div>
      </section>
    </main>
  );
}
