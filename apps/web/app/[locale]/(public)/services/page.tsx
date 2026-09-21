import { notFound } from "next/navigation";
import Link from "next/link";
import { ArrowRight, BarChart3, Briefcase, Cpu, Globe2, Leaf, Search, ShieldCheck, Sparkles, Users, Wallet } from "lucide-react";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getPublicProviderTaxonomy } from "@/modules/public/data/provider-intent/model";
import { getPublicServicesGuideMessages } from "@/modules/public/data/provider-intent/messages";
import { ServicesGuide } from "./services-guide";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";

const domainIcons = [Sparkles, Briefcase, Users, Cpu, Wallet, ShieldCheck, BarChart3, Globe2, Leaf, Search] as const;

export default async function ServicesTransition({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ q?: string | string[]; library?: string | string[] }> }) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const taxonomy = getPublicProviderTaxonomy(locale);
  const copy = getPublicServicesGuideMessages(locale);
  const initialQuery = typeof query.q === "string" ? query.q.slice(0, 120) : "";
  const initialLibrary = typeof query.library === "string" ? query.library.slice(0, 20).toUpperCase() : "";

  return (
    <main id="contenu-principal" className="public-page pb-16">
      <section className="public-wrap grid gap-10 py-14 lg:grid-cols-[1.15fr_.85fr] lg:items-center">
        <div>
          <p className="journey-eyebrow">{copy.eyebrow}</p>
          <h1>{copy.title}</h1>
          <p className="public-lead mt-4">{copy.description}</p>
        </div>
        <PublicPhoto scene="koutoubia" caption={locale === "ar" ? "مؤسسات أقوى لمغرب أكثر طموحاً" : "Des entreprises plus fortes pour un Maroc plus ambitieux"} />
      </section>
      <section className="public-wrap">
        <form className="journey-search" action={`/${locale}/services`} method="get" role="search">
          <label htmlFor="services-search">{copy.search}</label>
          <div>
            <Search aria-hidden="true" size={18} />
            <input id="services-search" name="q" type="search" defaultValue={initialQuery} maxLength={120} placeholder={copy.searchHint} />
            <button type="submit">{copy.searchAction}</button>
          </div>
        </form>
      </section>
      <section className="public-wrap mb-8 mt-8 grid gap-4 md:grid-cols-3">
        <Link href={`/${locale}/diagnostic`} className="public-card block no-underline">
          <h2>{locale === "ar" ? "أريد فهم صعوبة" : "Je veux comprendre une difficulté"}</h2>
          <p className="public-muted mt-2">{locale === "ar" ? "أصف وضعي وأحصل على توجيه خطوة بخطوة." : "Je décris ma situation et j’obtiens un guidage pas à pas."}</p>
        </Link>
        <Link href={`/${locale}/besoin`} className="public-card block no-underline">
          <h2>{locale === "ar" ? "لدي احتياج محدد" : "J’ai un besoin précis"}</h2>
          <p className="public-muted mt-2">{locale === "ar" ? "أعرف ما أبحث عنه وأتقدم بأسئلة قليلة." : "Je sais ce que je cherche et je réponds à quelques questions."}</p>
        </Link>
        <Link href={`/${locale}/fournisseur`} className="public-card block no-underline">
          <h2>{locale === "ar" ? "أريد اقتراح خبرتي" : "Je cherche à proposer mon expertise"}</h2>
          <p className="public-muted mt-2">{locale === "ar" ? "أنا مهني وأرغب في فهم فرص ماتريسيا." : "Je suis un professionnel et je souhaite comprendre les opportunités."}</p>
        </Link>
      </section>
      <section className="public-wrap" aria-labelledby="domains-title">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <h2 id="domains-title">{locale === "ar" ? "مجالات تدخلنا العشرة" : "Nos 10 domaines d’intervention"}</h2>
          <p className="public-muted max-w-xl">{locale === "ar" ? "هذه المجالات تصنيف داخلي لطرح الأسئلة المناسبة وتوجيهكم نحو الحلول الأنسب." : "Ces domaines sont une taxonomie interne qui nous permet de vous poser les bonnes questions et de vous orienter vers les solutions les plus pertinentes."}</p>
        </div>
        <div className="public-domain-grid">
          {(locale === "ar"
            ? [
                ["IT", "الرقمي ونظم المعلومات", "رقمنوا أنشطتكم وحسّنوا أدواتكم."],
                ["LOG", "التنظيم والأداء", "حسّنوا العمليات وعزّزوا فعالية فرقكم."],
                ["HR", "الموارد البشرية", "اجتذبوا وطوّروا واحتفظوا بالمواهب."],
                ["ACC", "المالية والتسيير", "أمّنوا تسييركم وقراراتكم."],
                ["SALES", "التسويق والتطوير التجاري", "حسّنوا تموقعكم ونمّوا سوقكم."],
                ["QHSE", "الجودة والامتثال والمخاطر", "عزّزوا معاييركم وتحكّموا في المخاطر."],
                ["COM", "الاستراتيجية والنمو", "وضّحوا الرؤية وهيكلوا مشاريعكم."],
                ["LEGAL", "القانون والحكامة", "أمّنوا الإطار القانوني والامتثال."],
                ["INS", "التأمين وإدارة المخاطر", "احموا نشاطكم بأدوات مناسبة."],
                ["BTP", "قطاعات متخصصة", "استكشفوا حلولاً مناسبة لقطاعكم."],
              ]
            : [
                ["COM", "Stratégie & croissance", "Clarifiez votre vision, structurez vos projets et accélérez votre développement."],
                ["LOG", "Organisation & performance", "Optimisez vos processus et renforcez l’efficacité de vos équipes."],
                ["HR", "Ressources humaines", "Attirez, développez et fidélisez vos talents."],
                ["IT", "Digital & systèmes d’information", "Digitalisez vos activités et améliorez vos outils."],
                ["ACC", "Finance & gestion", "Sécurisez votre gestion et vos décisions."],
                ["QHSE", "Qualité, conformité & risques", "Renforcez vos standards et maîtrisez vos risques."],
                ["SALES", "Marketing & développement commercial", "Mieux vous positionner et développer votre marché."],
                ["COM", "International & export", "Préparez votre expansion sur de nouveaux marchés."],
                ["QHSE", "Durabilité & impact", "Intégrez des pratiques plus responsables et durables."],
                ["BTP", "Secteurs spécifiques", "Explorez des solutions adaptées à votre secteur d’activité."],
              ] as const
          ).map(([code, name, text], index) => {
            const Icon = domainIcons[index] ?? Sparkles;
            return (
              <Link key={`${code}-${name}`} href={`/${locale}/besoin?library=${encodeURIComponent(code)}`} className="public-card block no-underline">
                <Icon aria-hidden="true" className="text-[#6d3cc7]" />
                <h3 className="mt-3">{name}</h3>
                <p className="public-muted mt-2">{text}</p>
                <span className="mt-3 inline-flex items-center gap-1 text-sm font-semibold text-[#6d3cc7]">{locale === "ar" ? "البدء" : "Commencer"}<ArrowRight className="rtl-mirror" size={14} /></span>
              </Link>
            );
          })}
        </div>
      </section>
      <section className="public-wrap mt-10">
        <div className="public-card max-w-none">
          <ServicesGuide locale={locale} libraries={taxonomy.libraries} initialQuery={initialQuery} initialLibrary={initialLibrary} />
        </div>
      </section>
      <section className="public-wrap journey-cta-band mt-10">
        <div>
          <h2>{locale === "ar" ? "مقاربة موجّهة، ليست كتالوجاً" : "Une approche guidée, pas un catalogue"}</h2>
          <p>{locale === "ar" ? "تساعد المجالات على فهم السياق والتوجه نحو الحلول المناسبة، دون فرض شراء." : "Nos domaines sont organisés selon une taxonomie interne. Ils vous permettent de mieux comprendre votre contexte et de vous orienter, qu’il s’agisse d’un accompagnement, d’un outil ou d’un expert."}</p>
        </div>
        <Link href={`/${locale}/diagnostic`} className="journey-primary">{locale === "ar" ? "بدء مساري" : "Commencer mon parcours"}<ArrowRight className="rtl-mirror" size={16} /></Link>
      </section>
    </main>
  );
}
