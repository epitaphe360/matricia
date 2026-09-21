import { ArrowRight, Building2, Handshake, LockKeyhole, Route, ShieldCheck, Sparkles, Store } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { getPublicMessages } from "../messages";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";

const detail = {
  fr: {
    statement: "Des expertises d’aujourd’hui pour les entreprises de demain",
    ctaPrimary: "Analyser mon entreprise",
    ctaSecondary: "Découvrir le parcours professionnel",
  },
  ar: {
    statement: "خبرات اليوم لمؤسسات الغد",
    ctaPrimary: "حلّلوا شركتي",
    ctaSecondary: "اكتشاف المسار المهني",
  },
} as const;

const icons = [Sparkles, ShieldCheck, Handshake, Route, LockKeyhole] as const;

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const copy = getPublicMessages(locale).about;
  return localizedRouteMetadata(locale, "/a-propos", copy.title, copy.description);
}

export default async function PublicAboutPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const copy = getPublicMessages(locale).about;
  const local = detail[locale];

  return (
    <main id="contenu-principal" tabIndex={-1} className="public-page pb-16">
      <section className="public-wrap grid gap-10 py-16 lg:grid-cols-[1.15fr_.85fr] lg:items-center">
        <div>
          <p className="journey-eyebrow">{copy.eyebrow}</p>
          <h1>{copy.title}</h1>
          <p className="public-lead mt-5">{copy.description}</p>
          <div className="journey-actions">
            <Link href={`/${locale}/diagnostic`} className="journey-primary">{local.ctaPrimary}<ArrowRight className="rtl-mirror" size={16} aria-hidden="true" /></Link>
            <Link href={`/${locale}/fournisseur`} className="journey-secondary">{local.ctaSecondary}</Link>
          </div>
        </div>
        <PublicPhoto scene="terrace" caption={local.statement} />
      </section>
      <section className="public-wrap grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {copy.principles.map((principle, index) => {
          const Icon = icons[index] ?? Sparkles;
          return (
            <article key={principle.title} className="public-card">
              <Icon aria-hidden="true" className="text-[#6d3cc7]" />
              <h2>{principle.title}</h2>
              <p className="public-muted">{principle.description}</p>
            </article>
          );
        })}
      </section>
      <section className="public-wrap mt-12">
        <p className="journey-eyebrow">{locale === "ar" ? "منظومة في خدمة المؤسسات" : "Un écosystème au service des entreprises"}</p>
        <h2 className="public-h2">{copy.approachTitle}</h2>
        <p className="public-lead mt-4">{copy.approachDescription}</p>
        <div className="public-ecosystem">
          <article>
            <Building2 aria-hidden="true" className="mx-auto text-[#6d3cc7]" />
            <h3 className="mt-2">{locale === "ar" ? "العميل" : "Client"}</h3>
            <p className="public-muted mt-1">{locale === "ar" ? "يعبّر عن احتياجاته ويقارن ويختار بثقة." : "Exprime ses besoins, compare et choisit en toute confiance."}</p>
          </article>
          <article className="is-hub">
            <strong>Matricia</strong>
            <p className="public-muted mt-2">{locale === "ar" ? "تنظّم وتربط وتؤمّن وترافق كل مرحلة." : "Structure, connecte, sécurise et accompagne chaque étape."}</p>
          </article>
          <article>
            <Store aria-hidden="true" className="mx-auto text-[#e07a5f]" />
            <h3 className="mt-2">{locale === "ar" ? "المهني" : "Professionnel"}</h3>
            <p className="public-muted mt-1">{locale === "ar" ? "يقترح خبرته ويستجيب للاحتياجات وينجز المهمة." : "Propose son expertise, répond aux besoins et réalise la mission."}</p>
          </article>
        </div>
        <article className="public-card mt-4 text-center">
          <h3>{locale === "ar" ? "شبكة الامتيازات" : "Réseau de franchises"}</h3>
          <p className="public-muted mt-2">{locale === "ar" ? "ارتكاز محلي لمرافقة المؤسسات على التراب وفق معايير ماتريسيا." : "Un ancrage local pour accompagner les entreprises sur tout le territoire, dans le respect des standards Matricia."}</p>
        </article>
      </section>
      <section className="public-wrap journey-cta-band mt-12">
        <div>
          <h2>{copy.ctaTitle}</h2>
          <p>{copy.ctaDescription}</p>
        </div>
        <Link href={`/${locale}/diagnostic`} className="journey-primary">{local.ctaPrimary}</Link>
      </section>
    </main>
  );
}
