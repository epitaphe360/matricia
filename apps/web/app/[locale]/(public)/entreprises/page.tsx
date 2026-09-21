import Link from "next/link";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { ArrowRight } from "lucide-react";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";

const copy = {
  fr: {
    title: "Entreprises",
    description: "Comprenez vos priorités, décrivez un besoin, comparez des devis adaptés et suivez vos engagements.",
    eyebrow: "PARCOURS CLIENT",
    lead: "Matricia accompagne votre entreprise du diagnostic à la validation des livrables, sans imposer un catalogue.",
    steps: [
      ["Comprendre ses priorités", "Un prédiagnostic indicatif clarifie ce qui freine réellement l’activité."],
      ["Décrire un besoin", "Vous précisez l’objectif, le périmètre et les contraintes utiles."],
      ["Recevoir des offres adaptées", "Seuls des professionnels autorisés pour le besoin reçoivent la consultation."],
      ["Comparer et choisir", "Vous lisez des devis structurés, sans classement opaque unique."],
      ["Suivre engagements et livrables", "Contrats, jalons et validations restent dans votre espace sécurisé."],
    ],
    where: "Où en êtes-vous ?",
    options: [
      ["Je ne sais pas par quoi commencer", "diagnostic", "Lancer le diagnostic"],
      ["Je connais mon besoin", "besoin", "Décrire mon besoin"],
      ["Je veux découvrir les offres Matricia", "abonnements", "Voir les offres"],
      ["J’ai déjà un compte", "connexion", "Me connecter"],
    ] as const,
    note: "L’aperçu ci-dessous est illustratif. Aucune donnée Client réelle n’est exposée.",
  },
  ar: {
    title: "المؤسسات",
    description: "افهموا أولوياتكم، صفوا احتياجاً، قارنوا عروضاً مناسبة وتابعوا التزاماتكم.",
    eyebrow: "مسار العميل",
    lead: "ترافق ماتريسيا مؤسستكم من التشخيص إلى المصادقة على التسليمات دون فرض كتالوج.",
    steps: [
      ["فهم الأولويات", "تقييم أولي إرشادي يوضح ما يبطئ النشاط فعلاً."],
      ["وصف الاحتياج", "تحددون الهدف والنطاق والقيود المفيدة."],
      ["استلام عروض مناسبة", "فقط المهنيون المصرح لهم بالاحتياج يتلقون الاستشارة."],
      ["المقارنة والاختيار", "تقرأون عروضاً منظمة دون ترتيب غامض وحيد."],
      ["متابعة الالتزامات والتسليمات", "تبقى العقود والمعالم والمصادقات في مساحتكم الآمنة."],
    ],
    where: "أين أنتم الآن؟",
    options: [
      ["لا أعرف من أين أبدأ", "diagnostic", "بدء التقييم"],
      ["أعرف احتياجي", "besoin", "وصف احتياجي"],
      ["أريد اكتشاف عروض ماتريسيا", "abonnements", "عرض العروض"],
      ["لدي حساب بالفعل", "connexion", "تسجيل الدخول"],
    ] as const,
    note: "المعاينة أدناه توضيحية. لا تُعرض أي بيانات عميل حقيقية.",
  },
} as const;

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const c = copy[locale];
  return localizedRouteMetadata(locale, "/entreprises", c.title, c.description);
}

export default async function PublicEntreprisesPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const c = copy[locale];

  return (
    <main id="contenu-principal" className="journey-home" dir={locale === "ar" ? "rtl" : "ltr"}>
      <section className="journey-home-hero">
        <div className="journey-hero-copy">
          <p className="journey-eyebrow">{c.eyebrow}</p>
          <h1>{c.title}</h1>
          <p className="journey-lead">{c.lead}</p>
        </div>
      </section>
      <section className="journey-home-section">
        <div className="journey-steps">
          {c.steps.map(([title, text], index) => (
            <article key={title}>
              <span>0{index + 1}</span>
              <h2>{title}</h2>
              <p>{text}</p>
            </article>
          ))}
        </div>
      </section>
      <section className="journey-home-section journey-value">
        <p className="journey-eyebrow">{c.where}</p>
        <div className="journey-value-grid">
          {c.options.map(([label, path, action]) => (
            <article key={path}>
              <h3>{label}</h3>
              <Link className="journey-known" href={`/${locale}/${path}`}>
                {action}
                <ArrowRight className="rtl-mirror" size={16} aria-hidden="true" />
              </Link>
            </article>
          ))}
        </div>
        <p className="mt-6 text-sm text-slate-600">{c.note}</p>
      </section>
    </main>
  );
}
