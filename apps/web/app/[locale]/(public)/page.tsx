import { ArrowRight, BriefcaseBusiness, Building2, CircleEllipsis, GraduationCap, HardHat, Landmark, Megaphone, Network, PackageCheck, Search, ShieldCheck, Sparkles, Users } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { PUBLIC_CATALOGUE_TOTALS } from "@/lib/public-catalogue/static-projection";
import { cn } from "@/lib/utils";
import { PublicCta, PublicShell } from "./_components/public-shell";
import { NumberedCard, SectionHeading } from "./_components/public-sections";
import { getPublicMessages } from "./messages";

const audienceIcons = [Building2, BriefcaseBusiness, Network] as const;
const libraryIcons = [Sparkles, ShieldCheck, Landmark, Megaphone, Users, PackageCheck, HardHat, CircleEllipsis] as const;

export default async function PublicHomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getPublicMessages(locale);
  const isArabic = locale === "ar";
  const ui = isArabic ? {
    badge: "منصة خدمات مهنية في المغرب",
    headline: <>مشاريعكم.<br />الخبراء المناسبون.<br /><span className="text-[#086ad8]">معاً نحو الأفضل.</span></>,
    intro: "المنصة المغربية التي تربط المؤسسات بمقدمي الخدمات والخبراء المؤهلين لإنجاز مشاريعهم المهنية.",
    searchPlaceholder: "ما الخدمة التي تبحث عنها؟",
    searchAction: "بحث",
    catalogueProof: `${PUBLIC_CATALOGUE_TOTALS.serviceCount} خدمة  |  ${PUBLIC_CATALOGUE_TOTALS.libraryCount} مكتبات  |  6000 سؤال خبرة`,
    servicesTitle: "استكشفوا خدماتنا",
    allServices: "عرض جميع الخدمات",
    profilesTitle: "حلول تناسب كل دور",
    journeyTitle: "مسار موثوق من البداية إلى التسليم",
    journey: ["احتياج واضح", "خبراء مؤهلون", "عقود مؤمنة", "تسليمات قابلة للتتبع"],
    profileActions: ["ابدأوا الآن", "انضموا إلينا", "اعرفوا المزيد"],
    finalTitle: "لنبنِ معاً مغرب الغد.",
    finalAction: "الانضمام إلى ماتريسيا",
  } : {
    badge: "Plateforme de services professionnels au Maroc",
    headline: <>Vos projets.<br />Les bons experts.<br /><span className="text-[#086ad8]">Plus loin, ensemble.</span></>,
    intro: "La plateforme marocaine qui connecte les entreprises, les prestataires et les experts qualifiés pour tous vos projets de services.",
    searchPlaceholder: "Quel service recherchez-vous ?",
    searchAction: "Rechercher",
    catalogueProof: `${PUBLIC_CATALOGUE_TOTALS.serviceCount} services  |  ${PUBLIC_CATALOGUE_TOTALS.libraryCount} bibliothèques  |  6 000 questions d’expertise`,
    servicesTitle: "Explorez nos services",
    allServices: "Voir tous les services",
    profilesTitle: "Des solutions pour chaque profil",
    journeyTitle: "Un parcours fiable, du besoin à la livraison",
    journey: ["Besoin clarifié", "Experts qualifiés", "Contrats sécurisés", "Livrables traçables"],
    profileActions: ["Découvrir", "Rejoindre", "En savoir plus"],
    finalTitle: "Construisons le Maroc de demain.",
    finalAction: "Rejoindre Matricia",
  };
  const visibleLibraries = messages.services.libraries.slice(0, 8);

  return <PublicShell locale={locale} alternatePath="" messages={messages.common}>
    <main id="contenu-principal">
      <section className="relative isolate overflow-hidden border-b bg-[#eef7ff] px-4 py-14 sm:px-6 sm:py-20 lg:px-8 lg:py-24">
        <div className="absolute inset-0 bg-[url('/matricia-home-hero-v1.png')] bg-cover bg-[70%_center] opacity-55" aria-hidden="true" />
        <div className="absolute inset-0 bg-gradient-to-r from-white via-white/95 to-white/5 rtl:bg-gradient-to-l" aria-hidden="true" />
        <div className="relative mx-auto max-w-7xl">
          <div className="max-w-2xl">
            <p className="inline-flex rounded-full bg-blue-100 px-3 py-1 text-xs font-bold text-blue-800">{ui.badge}</p>
            <h1 className="mt-5 text-4xl font-black leading-[1.02] tracking-[-0.045em] text-[#07192d] sm:text-6xl lg:text-7xl">{ui.headline}</h1>
            <p className="mt-6 max-w-xl text-base leading-7 text-slate-700 sm:text-lg">{ui.intro}</p>
            <form action={`/${locale}/services`} method="get" role="search" className="mt-7 flex max-w-xl rounded-xl border border-slate-300 bg-white p-1.5 shadow-lg shadow-blue-950/10 focus-within:ring-2 focus-within:ring-blue-500">
              <label htmlFor="public-service-search" className="sr-only">{ui.searchPlaceholder}</label>
              <Search aria-hidden="true" className="ms-3 mt-3 size-4 shrink-0 text-slate-400" />
              <input id="public-service-search" name="q" type="search" placeholder={ui.searchPlaceholder} className="min-w-0 flex-1 bg-transparent px-3 text-sm outline-none" />
              <button type="submit" className="min-h-11 rounded-lg bg-[#062b4f] px-5 text-sm font-bold text-white hover:bg-[#0a477b]">{ui.searchAction}</button>
            </form>
            <p className="mt-3 text-xs font-semibold text-slate-600" dir="ltr">{ui.catalogueProof}</p>
          </div>
        </div>
      </section>

      <section className="border-b bg-white px-4 py-8 sm:px-6 lg:px-8"><div className="mx-auto grid max-w-7xl grid-cols-2 gap-4 sm:grid-cols-4">{ui.journey.map((label, index) => { const icons = [Sparkles, ShieldCheck, BriefcaseBusiness, PackageCheck] as const; const Icon = icons[index]; return <div key={label} className="flex items-center gap-3 rounded-xl p-2"><span className="grid size-10 shrink-0 place-items-center rounded-full bg-blue-50 text-blue-700"><Icon aria-hidden="true" className="size-5" /></span><span className="text-sm font-bold text-slate-800">{label}</span></div>; })}</div></section>

      <section className="bg-white px-4 py-14 sm:px-6 lg:px-8"><div className="mx-auto max-w-7xl"><div className="flex items-end justify-between gap-4"><h2 className="text-2xl font-black tracking-tight text-[#07192d] sm:text-3xl">{ui.servicesTitle}</h2><Link href={`/${locale}/services`} className="inline-flex min-h-11 items-center gap-1 text-sm font-bold text-blue-700 hover:underline">{ui.allServices}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180" /></Link></div><div className="mt-7 grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-8">{visibleLibraries.map((library, index) => { const Icon = libraryIcons[index]; return <Link key={library.code} href={`/${locale}/services#${library.code.toLowerCase()}`} className="group rounded-2xl border border-slate-200 bg-white p-4 text-center shadow-sm transition hover:-translate-y-1 hover:border-blue-300 hover:shadow-md"><span className="mx-auto grid size-11 place-items-center rounded-xl bg-blue-50 text-blue-700 group-hover:bg-blue-700 group-hover:text-white"><Icon aria-hidden="true" className="size-5" /></span><span className="mt-3 block text-xs font-bold leading-5 text-slate-800">{library.name}</span></Link>; })}</div></div></section>

      <section className="bg-[#062b4f] px-4 py-14 text-white sm:px-6 lg:px-8"><div className="mx-auto max-w-7xl"><h2 className="text-2xl font-black tracking-tight sm:text-3xl">{ui.profilesTitle}</h2><div className="mt-8 grid gap-4 md:grid-cols-3">{messages.home.audiences.map((audience, index) => { const Icon = audienceIcons[index]; const href = index === 2 ? `/${locale}/franchise` : `/${locale}/connexion`; return <article key={audience.title} className="rounded-2xl border border-white/15 bg-white/10 p-6"><span className="grid size-11 place-items-center rounded-xl bg-white/10 text-blue-200"><Icon aria-hidden="true" className="size-5" /></span><h3 className="mt-5 text-xl font-bold">{audience.title}</h3><p className="mt-3 min-h-14 text-sm leading-6 text-white/70">{audience.description}</p><Link href={href} className="mt-5 inline-flex min-h-11 items-center gap-2 rounded-lg bg-white px-4 py-3 text-sm font-bold text-[#062b4f] hover:bg-blue-50">{ui.profileActions[index]}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180" /></Link></article>; })}</div></div></section>

      <section className="px-4 py-16 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-7xl"><SectionHeading eyebrow={messages.home.valueEyebrow} title={ui.journeyTitle} description={messages.home.valueDescription} /><ol className="mt-10 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">{messages.home.values.map((value, index) => <li key={value.title}><NumberedCard number={String(index + 1).padStart(2, "0")} title={value.title} description={value.description} /></li>)}</ol></div></section>

      <section className="relative overflow-hidden bg-[#dceeff] px-4 py-14 sm:px-6 lg:px-8"><div className="absolute -end-20 -top-24 size-72 rounded-full bg-blue-600/15" aria-hidden="true" /><div className="relative mx-auto flex max-w-7xl flex-col items-start justify-between gap-6 sm:flex-row sm:items-center"><div><h2 className="text-3xl font-black tracking-tight text-[#07192d]">{ui.finalTitle}</h2><p className="mt-2 text-slate-700">{messages.home.ctaDescription}</p></div><Link href={`/${locale}/connexion`} className={cn(buttonVariants({ size: "lg" }), "min-h-12 rounded-xl px-6")}>{ui.finalAction}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180" /></Link></div></section>
    </main>
  </PublicShell>;
}
