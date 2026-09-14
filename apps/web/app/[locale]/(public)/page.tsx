import Link from 'next/link';
import Image from 'next/image';
import { notFound } from 'next/navigation';
import { ArrowDown, ArrowUpRight, BriefcaseBusiness, Check, Fingerprint, Layers3, Search, ShieldCheck, Users } from 'lucide-react';
import { isLocale } from '@/lib/i18n/locale';
import { getStaticPublicCatalogue } from '@/lib/public-catalogue/static-projection';
import { getExperienceCopy } from '@/components/public-site/experience-copy';
import { ProjectStudio } from '@/components/public-site/project-studio';
import { MotionControl } from '@/components/public-site/motion-control';

export default async function PublicHomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const c = getExperienceCopy(locale);
  const catalogue = getStaticPublicCatalogue(locale);
  const trustIcons = [Fingerprint, Users, ShieldCheck, Check];
  return <main id="contenu-principal" tabIndex={-1} className="mx-experience">
    <section className="mx-hero">
      <div className="mx-hero-copy"><p className="mx-eyebrow"><span className="mx-status-dot" />{c.eyebrow}</p><h1>{c.title}<br />{c.titleMiddle}<br /><em>{c.titleEnd}</em></h1><p className="mx-lead">{c.intro}</p><div className="mx-actions"><a className="mx-button mx-button-light" href="#studio">{c.project}<ArrowUpRight aria-hidden="true" size={20} /></a><a className="mx-text-link" href="#collectif">{c.provider}<ArrowUpRight aria-hidden="true" size={18} /></a></div><a className="mx-scroll" href="#studio"><ArrowDown size={16} aria-hidden="true" />{c.scroll}</a></div>
      <div className="mx-constellation">
        <div className="mx-photo-frame"><Image src="/matricia-collaboration-v2.png" alt={c.imageAlt} fill priority sizes="(max-width: 760px) 100vw, 50vw" className="mx-hero-photo" /></div>
        <span className="mx-photo-spark" aria-hidden="true">✳</span>
        <div className="mx-floating mx-floating-client"><span className="mx-icon"><Users size={21} aria-hidden="true" /></span><strong>{c.client}</strong><small>{c.brief}</small></div>
        <div className="mx-floating mx-floating-experts"><span className="mx-icon"><BriefcaseBusiness size={21} aria-hidden="true" /></span><strong>{c.experts}</strong><small>{c.expertise}</small></div>
        <div className="mx-floating mx-floating-result"><span className="mx-icon"><ShieldCheck size={21} aria-hidden="true" /></span><strong>{c.result}</strong><small>{c.shared}</small></div>
        <MotionControl locale={locale} />
      </div>
    </section>
    <div className="mx-metrics"><div><strong>10</strong><span>{c.libraryLabel}</span></div><div><strong>200</strong><span>{c.serviceLabel}</span></div><div><strong>FR / AR</strong><span>{c.languageLabel}</span></div><span className="mx-metric-mark" aria-hidden="true">✳</span></div>
    <ProjectStudio locale={locale} />
    <section className="mx-section mx-expertise" id="expertises"><div className="mx-section-head"><span className="mx-eyebrow">{c.catalogueEyebrow}</span><h2>{c.catalogueTitle}</h2></div><form className="mx-search" action={`/${locale}/services`} role="search"><Search aria-hidden="true" /><label htmlFor="mx-search" className="sr-only">{c.search}</label><input id="mx-search" name="q" placeholder={c.searchHint} type="search" /><button className="mx-button" type="submit">{c.search}<ArrowUpRight size={18} aria-hidden="true" /></button></form><div className="mx-library-grid">{catalogue.libraries.map((l, i) => <Link href={`/${locale}/services?library=${l.code}`} className="mx-library" key={l.code}><span className="mx-number">{String(i + 1).padStart(2, '0')} /</span><Layers3 size={26} aria-hidden="true" /><h3>{l.name}</h3><ArrowUpRight className="mx-library-arrow" size={22} aria-hidden="true" /></Link>)}</div></section>
    <section className="mx-section mx-trust"><div className="mx-section-head"><span className="mx-eyebrow">{c.trustEyebrow}</span><h2>{c.trustTitle}</h2></div><ol className="mx-trust-grid">{c.trust.map(([title, description], i) => { const Icon = trustIcons[i]; return <li key={title}><span className="mx-trust-icon"><Icon aria-hidden="true" /></span><span className="mx-number">0{i + 1}</span><h3>{title}</h3><p>{description}</p></li>; })}</ol></section>
    <section className="mx-section mx-people" id="collectif"><div className="mx-section-head"><span className="mx-eyebrow">{c.peopleEyebrow}</span><h2>{c.peopleTitle}</h2></div><div className="mx-people-grid"><article><Users size={36} aria-hidden="true" /><span className="mx-eyebrow">{c.client}</span><h3>{c.clientTitle}</h3><p>{c.clientText}</p><Link className="mx-button" href={`/${locale}/services`}>{c.clientAction}<ArrowUpRight size={18} aria-hidden="true" /></Link></article><article><BriefcaseBusiness size={36} aria-hidden="true" /><span className="mx-eyebrow">{c.experts}</span><h3>{c.providerTitle}</h3><p>{c.providerText}</p><Link className="mx-button mx-button-light" href={`/${locale}/connexion`}>{c.providerAction}<ArrowUpRight size={18} aria-hidden="true" /></Link></article></div><div className="mx-franchise"><div><h3>{c.franchiseTitle}</h3><p>{c.franchiseText}</p></div><Link className="mx-text-link" href={`/${locale}/franchise`}>{c.franchiseAction}<ArrowUpRight size={20} aria-hidden="true" /></Link></div></section>
    <section className="mx-finale"><span className="mx-final-symbol" aria-hidden="true">✳</span><h2>{c.finalTitle}</h2><p>{c.finalText}</p><a href="#studio" className="mx-button mx-button-light">{c.project}<ArrowUpRight size={20} aria-hidden="true" /></a></section>
  </main>;
}
