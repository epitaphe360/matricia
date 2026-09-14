import Link from 'next/link';
import { notFound } from 'next/navigation';
import type { Metadata } from 'next';
import { isLocale } from '@/lib/i18n/locale';
import { localizedRouteMetadata } from '@/lib/seo/metadata';
import services from '@/lib/public-catalogue/services.json';
import { getExperienceCopy } from '@/components/public-site/experience-copy';
type Props = { params: Promise<{ locale: string; code: string }> };
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale, code } = await params;
  const service = services.find(s => s.code.toLowerCase() === code);
  if (!isLocale(locale) || !service) return {};
  return localizedRouteMetadata(locale, `/services/${code}`, service.name, service.description);
}
export default async function ServicePage({ params }: Props) {
  const { locale, code } = await params;
  const service = services.find(s => s.code.toLowerCase() === code);
  if (!isLocale(locale) || !service) notFound();
  const c = getExperienceCopy(locale);
  return <main id="contenu-principal" tabIndex={-1} className="mx-experience"><article className="mx-section mx-detail">
    <Link href={`/${locale}/services?library=${service.library}`} className="mx-text-link">← {c.back}</Link>
    {c.frenchNote && <p className="mt-6">{c.frenchNote}</p>}
    <h1 lang="fr" dir="ltr">{service.name}</h1><p lang="fr" dir="ltr">{service.description}</p>
    <h2>{c.deliverables}</h2><p lang="fr" dir="ltr">{service.deliverables}</p>
    <p>{c.sourceNote}</p><Link className="mx-button" href={`/${locale}/connexion`}>{c.request}</Link>
  </article></main>;
}
