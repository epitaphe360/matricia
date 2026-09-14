import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowUpRight } from 'lucide-react';
import { isLocale } from '@/lib/i18n/locale';
import { getStaticPublicCatalogue } from '@/lib/public-catalogue/static-projection';
import services from '@/lib/public-catalogue/services.json';
import { getExperienceCopy } from '@/components/public-site/experience-copy';

export default async function PublicServicesPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ q?: string | string[]; library?: string | string[] }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const query = await searchParams;
  const q = typeof query.q === 'string' ? query.q.slice(0, 200) : '';
  const library = typeof query.library === 'string' ? query.library : '';
  const c = getExperienceCopy(locale);
  const libraries = getStaticPublicCatalogue(locale).libraries;
  const normalize = (s: string) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLocaleLowerCase();
  const terms = normalize(q).split(/\s+/).filter(Boolean);
  const filtered = services.filter(s => (!library || library === s.library) && terms.every(term => normalize([s.name, s.code, s.description, libraries.find(l => l.code === s.library)?.name ?? ''].join(' ')).includes(term)));
  return <main id="contenu-principal" tabIndex={-1} className="mx-experience mx-catalogue"><section className="mx-section">
    <div className="mx-section-head"><span className="mx-eyebrow">{c.catalogueEyebrow}</span><h1 className="text-4xl sm:text-6xl tracking-tight mt-6">{c.catalogTitle}</h1></div>
    <form action={`/${locale}/services`} role="search"><div className="mx-search"><label className="sr-only" htmlFor="catalog-search">{c.search}</label><input type="search" id="catalog-search" name="q" defaultValue={q} placeholder={c.searchHint} /><button className="mx-button" type="submit">{c.search}</button></div><div className="mx-filter-row"><label htmlFor="library">{c.filter}<select id="library" name="library" defaultValue={library}><option value="">{c.allLibraries}</option>{libraries.map(l => <option value={l.code} key={l.code}>{l.name}</option>)}</select></label><Link href={`/${locale}/services`} className="mx-text-link">{c.reset}</Link></div></form>
    <p role="status">{filtered.length} {c.results}</p>{c.frenchNote && <p className="mt-4 text-sm">{c.frenchNote}</p>}
    <div className="mx-results">{filtered.map(s => <article className="mx-result-card" key={s.code} id={s.code.toLowerCase()}><span className="mx-eyebrow">{libraries.find(l => l.code === s.library)?.name}</span><h2 lang="fr" dir="ltr">{s.name}</h2><p lang="fr" dir="ltr">{s.deliverables}</p><Link className="mx-text-link" href={`/${locale}/services/${s.code.toLowerCase()}`}>{c.detail}<ArrowUpRight aria-hidden="true" size={18} /></Link></article>)}</div>
    {!filtered.length && <p className="py-12">{c.empty}</p>}
  </section></main>;
}
