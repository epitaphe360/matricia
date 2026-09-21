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
      <Link href={`/${locale}/client/abonnement`} className="public-wrap mt-4 inline-flex min-h-11 items-center font-semibold text-[#6d3cc7] underline underline-offset-4">{messages.manage}</Link>
    </main>
  );
}
