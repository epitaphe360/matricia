import { ArrowUpRight, Eye, Languages, LockKeyhole, Route } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { localizedRouteMetadata } from "@/lib/seo/metadata";
import { cn } from "@/lib/utils";
import { getPublicMessages } from "../messages";

const detail = {
  fr: {
    statement: "Une décision claire commence par les bonnes questions.",
    statementBody: "Matricia organise le passage d’une situation observée à une priorité comprise, puis à une action suivie. La technologie structure le parcours sans imposer sa complexité à l’utilisateur.",
    approachTitle: "Un cadre commun, sans parcours générique",
    approachBody: "Chaque organisation garde son contexte. Les questions, recommandations et preuves utiles restent rattachées au dossier concerné, avec des décisions compréhensibles par toutes les parties.",
    ctaPrimary: "Analyser mon entreprise",
    ctaSecondary: "J’ai un besoin précis",
  },
  ar: {
    statement: "القرار الواضح يبدأ بالأسئلة المناسبة.",
    statementBody: "تنظم ماتريسيا الانتقال من وضعية ملاحظة إلى أولوية مفهومة، ثم إلى إجراء قابل للتتبع. تنظم التقنية المسار دون فرض تعقيدها على المستخدم.",
    approachTitle: "إطار مشترك دون مسار موحد للجميع",
    approachBody: "تحتفظ كل مؤسسة بسياقها. وتظل الأسئلة والتوصيات والأدلة المفيدة مرتبطة بالملف المعني، مع قرارات مفهومة لجميع الأطراف.",
    ctaPrimary: "تحليل مؤسستي",
    ctaSecondary: "لدي احتياج محدد",
  },
} satisfies Record<Locale, Record<string, string>>;

const icons = [Eye, Route, LockKeyhole, Languages] as const;

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
  const local = detail[locale];

  return <main id="contenu-principal" tabIndex={-1} className="bg-[#f7f9fc] text-[#14213d]">
      <section className="relative isolate overflow-hidden border-b border-slate-200 px-4 py-16 sm:px-6 sm:py-24 lg:px-8 lg:py-28">
        <div aria-hidden="true" className="absolute -end-24 -top-24 -z-10 size-80 rounded-full bg-blue-100/70 blur-3xl" />
        <div className="mx-auto grid max-w-6xl items-end gap-12 lg:grid-cols-[1.45fr_.55fr]">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-blue-700 rtl:tracking-normal">{copy.eyebrow}</p>
            <h1 className="mt-5 max-w-4xl text-4xl font-semibold leading-[1.08] tracking-[-0.035em] text-balance sm:text-6xl rtl:tracking-normal">{copy.title}</h1>
            <p className="mt-6 max-w-3xl text-lg leading-8 text-slate-600">{copy.description}</p>
          </div>
          <div className="border-s-2 border-[#b49a6c] ps-6"><p className="text-xl font-semibold leading-8 text-[#0b1739]">{local.statement}</p></div>
        </div>
      </section>

      <section className="px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[.72fr_1.28fr] lg:gap-20">
        <div><p className="text-sm font-semibold text-blue-700">01</p><h2 className="mt-3 text-3xl font-semibold tracking-[-0.025em] sm:text-4xl rtl:tracking-normal">{copy.missionTitle}</h2></div>
        <div><p className="text-xl leading-9 text-slate-700">{copy.missionDescription}</p><p className="mt-6 leading-8 text-slate-600">{local.statementBody}</p></div>
      </div></section>

      <section className="border-y border-slate-200 bg-white px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-6xl">
        <div className="max-w-2xl"><p className="text-sm font-semibold text-blue-700">02</p><h2 className="mt-3 text-3xl font-semibold tracking-[-0.025em] sm:text-4xl rtl:tracking-normal">{copy.principlesTitle}</h2></div>
        <div className="mt-10 grid gap-px overflow-hidden rounded-3xl border border-slate-200 bg-slate-200 sm:grid-cols-2 lg:grid-cols-4">
          {copy.principles.map((principle, index) => {
            const Icon = icons[index];
            return <article key={principle.title} className="min-h-64 bg-white p-6 sm:p-7"><div className="flex items-center justify-between"><span className="grid size-11 place-items-center rounded-xl bg-blue-50 text-blue-700"><Icon aria-hidden="true" className="size-5" /></span><span aria-hidden="true" className="text-sm font-semibold tabular-nums text-slate-600">0{index + 1}</span></div><h3 className="mt-10 text-xl font-semibold text-[#0b1739]">{principle.title}</h3><p className="mt-3 leading-7 text-slate-600">{principle.description}</p></article>;
          })}
        </div>
      </div></section>

      <section className="px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-6xl rounded-3xl bg-[#0b1739] p-7 text-white sm:p-12 lg:grid lg:grid-cols-[.8fr_1.2fr] lg:gap-16">
        <p className="text-sm font-semibold text-blue-200">03</p><div className="mt-4 lg:mt-0"><h2 className="text-3xl font-semibold tracking-[-0.025em] sm:text-4xl rtl:tracking-normal">{local.approachTitle}</h2><p className="mt-5 text-lg leading-8 text-slate-300">{local.approachBody}</p></div>
      </div></section>

      <section className="border-t border-slate-200 bg-white px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto flex max-w-6xl flex-col justify-between gap-8 md:flex-row md:items-center">
        <div className="max-w-2xl"><h2 className="text-3xl font-semibold tracking-[-0.025em] rtl:tracking-normal">{copy.ctaTitle}</h2><p className="mt-3 leading-7 text-slate-600">{copy.ctaDescription}</p></div>
        <div className="flex flex-col gap-3 sm:flex-row"><Link href={`/${locale}/besoin`} className={cn(buttonVariants({ variant: "outline", size: "lg" }), "min-h-12 rounded-xl border-slate-400 px-6")}>{local.ctaSecondary}</Link><Link href={`/${locale}/diagnostic`} className={cn(buttonVariants({ size: "lg" }), "min-h-12 rounded-xl bg-blue-700 px-6 hover:bg-blue-800")}>{local.ctaPrimary}<ArrowUpRight aria-hidden="true" className="size-4 rtl:-scale-x-100" /></Link></div>
      </div></section>
  </main>;
}
