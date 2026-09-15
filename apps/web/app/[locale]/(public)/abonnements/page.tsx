import type { Metadata } from "next";
import Link from "next/link";
import { CheckCircle2 } from "lucide-react";
import { notFound } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { localizedRouteMetadata } from "@/lib/seo/metadata";
import { formatPublicMoney } from "@/lib/public-subscriptions/money";
import { loadPublicSubscriptionPlans } from "@/lib/public-subscriptions/repository";

const copy = {
  fr: { title: "Abonnements Matricia", description: "Découvrez les offres publiées avant de créer votre compte.", monthly: "par mois", annual: "par an", credits: "crédits commerciaux mensuels inclus", unavailable: "Les conditions tarifaires sont en cours de publication. Vous pouvez créer votre compte sans choisir une offre aujourd’hui.", action: "Créer un compte", manage: "Déjà client ? Gérer mon abonnement", note: "Les crédits commerciaux ne constituent ni un compte bancaire ni une somme retirable. Le détail contractuel applicable est confirmé dans votre espace avant toute souscription." },
  ar: { title: "اشتراكات ماتريسيا", description: "اطلعوا على العروض المنشورة قبل إنشاء حسابكم.", monthly: "شهرياً", annual: "سنوياً", credits: "أرصدة تجارية شهرية مشمولة", unavailable: "شروط الأسعار قيد النشر. يمكنكم إنشاء حساب دون اختيار عرض الآن.", action: "إنشاء حساب", manage: "لديكم حساب؟ إدارة الاشتراك", note: "الأرصدة التجارية ليست حساباً بنكياً ولا مبلغاً قابلاً للسحب. يتم تأكيد التفاصيل التعاقدية داخل فضائكم قبل أي اشتراك." },
} as const;

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  return localizedRouteMetadata(locale, "/abonnements", copy[locale].title, copy[locale].description);
}

export default async function PublicSubscriptionsPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = copy[locale];
  const result = await loadPublicSubscriptionPlans();
  return <main id="contenu-principal" className="bg-[#f7f9fc] px-4 py-16 text-[#14213d] sm:px-6 sm:py-24">
    <div className="mx-auto max-w-6xl">
      <p className="text-sm font-semibold uppercase tracking-[0.16em] text-blue-700">Matricia</p>
      <h1 className="mt-4 text-4xl font-semibold tracking-tight text-[#0b1739] sm:text-6xl">{messages.title}</h1>
      <p className="mt-5 max-w-2xl text-lg leading-8 text-slate-600">{messages.description}</p>
      {result.status === "success" && result.plans.length > 0 ? <ul className="mt-12 grid gap-5 lg:grid-cols-3">{result.plans.map((plan) => <li key={plan.id} className="rounded-3xl border border-slate-200 bg-white p-7 shadow-sm">
        <h2 className="text-2xl font-semibold text-[#0b1739]">{plan.code}</h2>
        <p className="mt-6 text-3xl font-semibold">{formatPublicMoney(plan.monthlyPriceMinor, plan.currency, locale)} <span className="text-sm font-normal text-slate-500">{messages.monthly}</span></p>
        <p className="mt-2 text-sm text-slate-600">{formatPublicMoney(plan.annualPriceMinor, plan.currency, locale)} {messages.annual}</p>
        <p className="mt-5 flex items-start gap-2 text-sm text-slate-600"><CheckCircle2 aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-blue-700" />{plan.monthlyCreditGrant} {messages.credits}</p>
        <Link href={`/${locale}/connexion?mode=inscription&role=client`} className="mt-7 inline-flex min-h-11 items-center justify-center rounded-xl bg-blue-700 px-5 py-3 font-semibold text-white hover:bg-blue-800">{messages.action}</Link>
      </li>)}</ul> : <p role="status" className="mt-10 rounded-2xl border border-amber-200 bg-amber-50 p-5 text-amber-950">{messages.unavailable}</p>}
      <p className="mt-8 max-w-3xl text-sm leading-6 text-slate-600">{messages.note}</p>
      <Link href={`/${locale}/client/abonnement`} className="mt-4 inline-flex min-h-11 items-center font-semibold text-blue-700 underline underline-offset-4">{messages.manage}</Link>
    </div>
  </main>;
}
