import { ArrowUpRight, BadgeCheck, ChartNoAxesCombined, Network, ShieldCheck } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { localizedRouteMetadata } from "@/lib/seo/metadata";
import { cn } from "@/lib/utils";
import { getPublicMessages } from "../messages";

const localCopy = {
  fr: {
    label: "Un modèle structuré pour agir localement",
    frameworkLead: "Le cadre protège la qualité des décisions et la confiance entre entreprises, professionnels et responsables de réseau.",
    cta: "Engager la démarche",
    note: "L’accès à l’espace franchisé dépend des validations et permissions prévues par Matricia.",
  },
  ar: {
    label: "نموذج منظم للعمل محلياً",
    frameworkLead: "يحمي الإطار جودة القرارات والثقة بين المؤسسات والمهنيين ومسؤولي الشبكة.",
    cta: "بدء المسار",
    note: "يخضع الوصول إلى فضاء الامتياز للمصادقات والصلاحيات المعتمدة لدى ماتريسيا.",
  },
} satisfies Record<Locale, Record<string, string>>;

const roleIcons = [Network, BadgeCheck, ChartNoAxesCombined] as const;

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const copy = getPublicMessages(locale).franchise;
  return localizedRouteMetadata(locale, "/franchise", copy.title, copy.description);
}

export default async function PublicFranchisePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getPublicMessages(locale);
  const copy = messages.franchise;
  const local = localCopy[locale];

  return <main id="contenu-principal" tabIndex={-1} className="bg-[#f7f9fc] text-[#14213d]">
      <section className="relative isolate overflow-hidden bg-[#0b1739] px-4 py-16 text-white sm:px-6 sm:py-24 lg:px-8 lg:py-28">
        <div aria-hidden="true" className="absolute -end-32 top-1/2 -z-10 size-96 -translate-y-1/2 rounded-full border-[80px] border-blue-800/30" />
        <div className="mx-auto max-w-6xl"><div className="max-w-4xl"><p className="text-sm font-semibold uppercase tracking-[0.16em] text-blue-300 rtl:tracking-normal">{copy.eyebrow}</p><h1 className="mt-5 text-4xl font-semibold leading-[1.08] tracking-[-0.035em] text-balance sm:text-6xl rtl:tracking-normal">{copy.title}</h1><p className="mt-6 max-w-3xl text-lg leading-8 text-slate-300">{copy.description}</p></div>
          <div className="mt-10 inline-flex items-center gap-3 rounded-2xl border border-white/15 bg-white/5 px-5 py-4 text-sm font-medium text-slate-200"><ShieldCheck aria-hidden="true" className="size-5 text-[#d2ba8f]" /><span>{local.label}</span></div>
        </div>
      </section>

      <section className="px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto max-w-6xl"><div className="max-w-3xl"><p className="text-sm font-semibold uppercase tracking-[0.14em] text-blue-700 rtl:tracking-normal">01</p><h2 className="mt-3 text-3xl font-semibold tracking-[-0.025em] sm:text-4xl rtl:tracking-normal">{copy.roleTitle}</h2><p className="mt-4 text-lg leading-8 text-slate-600">{copy.roleDescription}</p></div>
        <div className="mt-10 grid gap-5 lg:grid-cols-3">{copy.roles.map((role, index) => { const Icon = roleIcons[index]; return <article key={role.title} className="group rounded-3xl border border-slate-200 bg-white p-7 transition-transform duration-200 hover:-translate-y-1 motion-reduce:transform-none"><span className="grid size-12 place-items-center rounded-2xl bg-blue-50 text-blue-700"><Icon aria-hidden="true" className="size-6" /></span><h3 className="mt-8 text-xl font-semibold text-[#0b1739]">{role.title}</h3><p className="mt-3 leading-7 text-slate-600">{role.description}</p></article>; })}</div>
      </div></section>

      <section className="border-y border-slate-200 bg-white px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[.8fr_1.2fr] lg:gap-20"><div><p className="text-sm font-semibold uppercase tracking-[0.14em] text-blue-700 rtl:tracking-normal">02</p><h2 className="mt-3 text-3xl font-semibold tracking-[-0.025em] sm:text-4xl rtl:tracking-normal">{copy.frameworkTitle}</h2><p className="mt-5 leading-8 text-slate-600">{local.frameworkLead}</p></div><ol className="divide-y divide-slate-200 border-y border-slate-200">{copy.framework.map((item, index) => <li key={item} className="flex gap-5 py-6"><span aria-hidden="true" className="mt-0.5 text-sm font-bold tabular-nums text-blue-700">0{index + 1}</span><span className="text-lg leading-8 text-slate-700">{item}</span></li>)}</ol></div></section>

      <section className="px-4 py-14 sm:px-6 sm:py-20 lg:px-8"><div className="mx-auto flex max-w-6xl flex-col justify-between gap-8 rounded-3xl bg-blue-50 p-7 sm:p-10 md:flex-row md:items-center"><div className="max-w-2xl"><h2 className="text-3xl font-semibold tracking-[-0.025em] text-[#0b1739] rtl:tracking-normal">{copy.ctaTitle}</h2><p className="mt-3 leading-7 text-slate-600">{copy.ctaDescription}</p><p className="mt-4 text-sm leading-6 text-slate-700">{local.note}</p></div><Link href={`/${locale}/connexion`} className={cn(buttonVariants({ size: "lg" }), "min-h-12 shrink-0 rounded-xl bg-blue-700 px-6 hover:bg-blue-800")}>{local.cta}<ArrowUpRight aria-hidden="true" className="size-4 rtl:-scale-x-100" /></Link></div></section>
  </main>;
}
