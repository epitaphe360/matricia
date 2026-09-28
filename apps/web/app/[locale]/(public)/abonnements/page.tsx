import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { formatMinor } from "@/modules/shared/lib/subscriptions/model";
import { loadPublicSubscriptionPlans, type PublicSubscriptionPlan } from "@/modules/public/data/subscriptions/repository";
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
    tariff: "Tarif communiqué avant souscription",
    action: "Sur demande",
    manage: "Déjà client ? Gérer mon abonnement",
    contact: "Nous contacter",
    discover: "Découvrir le parcours",
    note: "Les conditions et fonctionnalités applicables sont confirmées avant souscription. Aucun prix n’est inventé sur cette page.",
    ctaTitle: "Prêt à simplifier vos projets ?",
    ctaText: "Découvrez la formule qui vous convient et échangez avec notre équipe pour en savoir plus.",
    funds: "L’abonnement finance l’accès aux outils Matricia : diagnostic, demandes, comparaison, suivi et documents. Il ne finance pas les honoraires du professionnel, qui fixe ses propres prix.",
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
    tariff: "يُبلَّغ السعر قبل الاشتراك",
    action: "عند الطلب",
    manage: "لديكم حساب؟ إدارة الاشتراك",
    contact: "اتصلوا بنا",
    discover: "اكتشاف المسار",
    note: "تُؤكد الشروط والوظائف المطبقة قبل الاشتراك. لا يُعرض أي سعر مخترع في هذه الصفحة.",
    ctaTitle: "جاهزون لتبسيط مشاريعكم؟",
    ctaText: "اكتشفوا الصيغة المناسبة وتبادلوا مع فريقنا لمعرفة المزيد.",
    funds: "يموّل الاشتراك الوصول إلى أدوات ماتريسيا: التشخيص والطلبات والمقارنة والمتابعة والوثائق. ولا يموّل أتعاب المهني، الذي يحدد أسعاره بنفسه.",
    pillars: [["أدوات ملموسة للانتقال إلى التنفيذ"], ["تجربة مؤمنة وسرية"], ["مرافقة في كل مرحلة"]],
  },
} as const;

const planNames = {
  PREMIUM: { fr: "Premium", ar: "بريميوم" },
  GOLD: { fr: "Gold", ar: "غولد" },
  PLATINUM: { fr: "Platinum", ar: "بلاتينيوم" },
} as const;

function creditCount(value: string, locale: "fr" | "ar") {
  return new Intl.NumberFormat(locale === "ar" ? "ar-MA" : "fr-MA", { maximumFractionDigits: 0 }).format(BigInt(value));
}

function publishedPrice(plan: PublicSubscriptionPlan) {
  return BigInt(plan.monthlyPriceMinor) > BigInt(0) ? plan.monthlyPriceMinor : null;
}

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
      <section className="public-hero-split">
        <div>
          <p className="journey-eyebrow">{messages.eyebrow}</p>
          <h1>{messages.headline}</h1>
          <p className="public-lead mt-4">{messages.description}</p>
          <ul className="journey-trust">
            {messages.pillars.map(([item]) => <li key={item}>{item}</li>)}
          </ul>
        </div>
        <PublicPhoto scene="lantern" caption={locale === "ar" ? "مشاريع اليوم لمغرب الغد" : "Des projets d’aujourd’hui pour un Maroc de demain"} />
      </section>
      <p className="public-wrap mt-8 text-sm leading-6 text-slate-700">{messages.funds}</p>
      {plans.length ? (
        <ul className="public-wrap public-plans">
          {plans.map((plan) => {
            const price = publishedPrice(plan);
            return (
              <li key={plan.id}>
                <article className={plan.code === "GOLD" ? "is-featured" : undefined}>
                  <h2>{planNames[plan.code][locale]}</h2>
                  <p className="mt-3 text-2xl font-semibold" dir="ltr">
                    {price ? formatMinor(price, plan.currency, locale) : messages.tariff}
                  </p>
                  {price ? <p className="text-sm text-slate-600">{messages.monthly}</p> : null}
                  {BigInt(plan.annualPriceMinor) > BigInt(0) ? (
                    <p className="mt-1 text-sm text-slate-600" dir="ltr">{formatMinor(plan.annualPriceMinor, plan.currency, locale)} {messages.annual}</p>
                  ) : null}
                  <p className="mt-4 text-sm text-slate-700"><span dir="ltr">{creditCount(plan.monthlyCreditGrant, locale)}</span> {messages.credits}</p>
                  <Link href={`/${locale}/contact?motif=CLIENT&plan=${encodeURIComponent(plan.code)}`} className="journey-secondary mt-6 w-full">{messages.action}</Link>
                </article>
              </li>
            );
          })}
        </ul>
      ) : (
        <div className="public-wrap">
          <p role="status" className="rounded-2xl border border-amber-200 bg-amber-50 p-5 text-amber-950">{messages.unavailable}</p>
          <Link href={`/${locale}/contact?motif=CLIENT`} className="journey-secondary mt-6">{messages.contact}</Link>
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
      <section className="public-wrap mt-12">
        <h2 className="public-h2">{locale === "ar" ? "أسئلة متكررة" : "Questions fréquentes"}</h2>
        <p className="public-muted mt-3">{locale === "ar" ? "ما تحتاجون معرفته عن الاشتراكات والتجربة والأرصدة." : "Tout ce que vous devez savoir sur nos abonnements, l’essai et la gestion des crédits."}</p>
        <div className="journey-faq">
          {(locale === "ar"
            ? [
                ["هل يمكن تجربة ماتريسيا قبل الاشتراك؟", "نعم. التجربة المتاحة في المساحة العميلة تبقى محدودة زمنياً ولا تُحوَّل إلى اشتراك دون تأكيدكم."],
                ["كيف تعمل الأرصدة؟", "الأرصدة تُقيَّد في دفتر غير قابل للتعديل. الرصيد المعروض يُشتق من الحركات، ولا يُغيَّر يدوياً."],
                ["ما هي Box؟", "Box حزمة منافع مرتبطة بالخطة. محتواها وشروطها تُؤكَّد عند التفعيل في المساحة الآمنة."],
                ["هل يمكن تغيير الصيغة لاحقاً؟", "نعم، من مساحة الاشتراك بعد الاتصال. أي تغيير يُطبَّق وفق القواعد النشطة للخطة."],
                ["ماذا يحدث عند نهاية فترة التجربة؟", "إذا لم تُفعَّل خطة Gold نشطة، تُقيَّد بعض الإجراءات الجديدة. التاريخ والمحتوى المحفوظان يبقيان."],
                ["كيف أدير اشتراكي من حسابي؟", "بعد الاتصال، الصفحة Client / Abonnement يعرض الخطة والدورة والحركات المرتبطة."],
              ]
            : [
                ["Puis-je essayer Matricia avant de m’abonner ?", "Oui. L’essai disponible dans l’espace Client est limité dans le temps et ne se convertit pas en abonnement sans votre confirmation."],
                ["Comment fonctionnent les crédits ?", "Les crédits sont inscrits dans un ledger immuable. Le solde affiché est dérivé des mouvements ; il n’est jamais modifié manuellement."],
                ["Qu’est-ce qu’une Box ?", "Une Box est un ensemble de bénéfices lié à un plan. Son contenu et ses conditions sont confirmés à l’activation, dans l’espace sécurisé."],
                ["Puis-je changer de formule plus tard ?", "Oui, depuis l’espace abonnement après connexion. Tout changement s’applique selon les règles actives du plan."],
                ["Que se passe-t-il à la fin de ma période d’essai ?", "Sans plan Gold actif, certaines nouvelles actions sont restreintes. L’historique et le contenu déjà enregistrés restent disponibles."],
                ["Comment gérer mon abonnement depuis mon compte ?", "Après connexion, la page Client / Abonnement affiche le plan, le cycle et les mouvements associés."],
              ]
          ).map(([question, answer]) => (
            <details key={question}>
              <summary>{question}<span aria-hidden="true">+</span></summary>
              <p>{answer}</p>
            </details>
          ))}
        </div>
      </section>
      <Link href={`/${locale}/client/abonnement`} className="public-wrap mt-4 inline-flex min-h-11 items-center font-semibold text-[var(--mat-violet)] underline underline-offset-4">{messages.manage}</Link>
    </main>
  );
}
