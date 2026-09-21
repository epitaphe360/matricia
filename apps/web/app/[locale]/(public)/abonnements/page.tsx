import type { Metadata } from "next";
import Link from "next/link";
import { CheckCircle2 } from "lucide-react";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { loadPublicSubscriptionPlans } from "@/modules/public/data/subscriptions/repository";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";

const copy = {
  fr: {
    eyebrow: "Abonnements",
    title: "Abonnements Matricia",
    headline: "Des formules adaptées à vos besoins professionnels",
    description: "Accédez aux outils Matricia pour simplifier vos projets, collaborer avec des professionnels qualifiés et garder le contrôle à chaque étape.",
    monthly: "par mois",
    annual: "par an",
    credits: "crédits commerciaux mensuels inclus",
    unavailable: "Les conditions tarifaires sont confirmées avant souscription. Vous pouvez créer votre compte ou nous contacter dès aujourd’hui.",
    action: "Sur demande",
    manage: "Déjà client ? Gérer mon abonnement",
    contact: "Nous contacter",
    discover: "Découvrir le parcours",
    note: "Les conditions et fonctionnalités applicables sont confirmées avant souscription. Aucun prix n’est inventé sur cette page.",
    ctaTitle: "Prêt à simplifier vos projets ?",
    ctaText: "Découvrez la formule qui vous convient et échangez avec notre équipe pour en savoir plus.",
    features: ["Diagnostic de projet", "Demandes structurées", "Comparaison de devis", "Suivi des missions", "Gestion des documents", "Support par email"],
    pillars: [["Des outils concrets pour passer à l’action"], ["Une expérience sécurisée et confidentielle"], ["Un accompagnement à chaque étape"]],
  },
  ar: {
    eyebrow: "الاشتراكات",
    title: "اشتراكات ماتريسيا",
    headline: "صيغ مناسبة لاحتياجاتكم المهنية",
    description: "ادخلوا إلى أدوات ماتريسيا لتبسيط مشاريعكم والتعاون مع مهنيين مؤهلين والاحتفاظ بالتحكم في كل مرحلة.",
    monthly: "شهرياً",
    annual: "سنوياً",
    credits: "أرصدة تجارية شهرية مشمولة",
    unavailable: "تُؤكد الشروط قبل الاشتراك. يمكنكم إنشاء حساب أو التواصل معنا الآن.",
    action: "عند الطلب",
    manage: "لديكم حساب؟ إدارة الاشتراك",
    contact: "اتصلوا بنا",
    discover: "اكتشاف المسار",
    note: "تُؤكد الشروط والوظائف المطبقة قبل الاشتراك. لا يُعرض أي سعر مخترع في هذه الصفحة.",
    ctaTitle: "جاهزون لتبسيط مشاريعكم؟",
    ctaText: "اكتشفوا الصيغة المناسبة وتبادلوا مع فريقنا لمعرفة المزيد.",
    features: ["تشخيص المشروع", "طلبات منظمة", "مقارنة العروض", "متابعة المهام", "تدبير الوثائق", "دعم عبر البريد"],
    pillars: [["أدوات ملموسة للانتقال إلى التنفيذ"], ["تجربة مؤمنة وسرية"], ["مرافقة في كل مرحلة"]],
  },
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
  const plans = result.status === "success" ? result.plans : [];

  return (
    <main id="contenu-principal" className="public-page pb-16">
      <section className="public-wrap grid gap-10 py-16 lg:grid-cols-[1.1fr_.9fr] lg:items-center">
        <div>
          <p className="journey-eyebrow">{messages.eyebrow}</p>
          <h1>{messages.title}</h1>
          <p className="public-lead mt-4">{messages.headline}</p>
          <p className="public-lead mt-3">{messages.description}</p>
          <ul className="journey-trust">
            {messages.pillars.map(([item]) => <li key={item}>{item}</li>)}
          </ul>
        </div>
        <PublicPhoto scene="lantern" caption={locale === "ar" ? "مشاريع اليوم لمغرب الغد" : "Des projets d’aujourd’hui pour un Maroc de demain"} />
      </section>
      {plans.length ? (
        <ul className="public-wrap public-plans">
          {plans.map((plan, index) => (
            <li key={plan.id}>
              <article className={index === 1 ? "is-featured" : undefined}>
                <h2>{plan.code}</h2>
                <p className="mt-2 text-sm text-slate-600">{messages.note}</p>
                <ul className="mt-5 space-y-2 text-sm text-slate-700">
                  {messages.features.map((feature) => (
                    <li key={feature} className="flex items-start gap-2"><CheckCircle2 aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-[#3d6b55]" />{feature}</li>
                  ))}
                </ul>
                <Link href={`/${locale}/contact?motif=CLIENT&plan=${encodeURIComponent(plan.code)}`} className="journey-secondary mt-6 w-full">{messages.action}</Link>
              </article>
            </li>
          ))}
        </ul>
      ) : (
        <div className="public-wrap">
          <p role="status" className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-amber-950">{messages.unavailable}</p>
          <div className="public-plans mt-8">
            {["Essentiel", "Premium", "Organisation"].map((name, index) => (
              <article key={name} className={index === 1 ? "is-featured" : undefined}>
                <h2>{name}</h2>
                <p className="mt-2 text-sm text-slate-600">{locale === "ar" ? "وظائف المسار، تؤكد قبل الاشتراك." : "Fonctionnalités adaptées à votre parcours, confirmées avant souscription."}</p>
                <ul className="mt-5 space-y-2 text-sm text-slate-700">
                  {messages.features.map((feature) => (
                    <li key={feature} className="flex items-start gap-2"><CheckCircle2 aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-[#3d6b55]" />{feature}</li>
                  ))}
                </ul>
                <Link href={`/${locale}/contact?motif=CLIENT`} className="journey-secondary mt-6 w-full">{messages.action}</Link>
              </article>
            ))}
          </div>
        </div>
      )}
      <p className="public-wrap mt-6 text-sm text-slate-600">{messages.note}</p>
      <section className="public-wrap journey-cta-band mt-10">
        <div>
          <h2>{messages.ctaTitle}</h2>
          <p>{messages.ctaText}</p>
        </div>
        <div className="flex flex-wrap gap-3">
          <Link className="journey-primary" href={`/${locale}/diagnostic`}>{messages.discover}</Link>
          <Link className="journey-secondary" href={`/${locale}/contact`}>{messages.contact}</Link>
        </div>
      </section>
      <Link href={`/${locale}/client/abonnement`} className="public-wrap mt-4 inline-flex min-h-11 items-center font-semibold text-[#6d3cc7] underline underline-offset-4">{messages.manage}</Link>
    </main>
  );
}
