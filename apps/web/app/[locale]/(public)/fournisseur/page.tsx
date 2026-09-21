import { CheckCircle2 } from "lucide-react";
import type { Metadata } from "next";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { getPublicProviderTaxonomy } from "@/modules/public/data/provider-intent/model";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { ProviderTaxonomySelector } from "./provider-taxonomy-selector";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";
import Link from "next/link";

export async function generateMetadata({ params }: { params: Promise<{ locale: Locale }> }): Promise<Metadata> {
  const { locale } = await params;
  const copy = getPublicJourneyCopy(locale).provider;
  return localizedRouteMetadata(locale, "/fournisseur", copy.title, copy.intro);
}

export default async function ProviderEntry({ params }: { params: Promise<{ locale: Locale }> }) {
  const { locale } = await params;
  const copy = getPublicJourneyCopy(locale).provider;
  const taxonomy = getPublicProviderTaxonomy(locale);

  return (
    <main id="contenu-principal" className="public-page pb-16">
      <section className="public-hero-split">
        <div>
          <p className="journey-eyebrow">{copy.eyebrow}</p>
          <h1>{copy.title}</h1>
          <p className="public-lead mt-4">{copy.intro}</p>
          <div className="journey-actions">
            <a className="journey-primary" href="#inscription-guidee">{copy.begin}</a>
            <Link className="journey-secondary" href={`/${locale}/connexion?next=${encodeURIComponent(`/${locale}/sous-traitant/qualification`)}`}>{copy.existing}</Link>
          </div>
          <ul className="journey-trust">
            {copy.trust.map((item) => <li key={item}><CheckCircle2 size={16} aria-hidden="true" />{item}</li>)}
          </ul>
        </div>
        <PublicPhoto scene="craftsman" caption={locale === "ar" ? "موهبة مهنية تبني مغرباً مستداماً" : "Le talent professionnel bâtit un Maroc durable"} />
      </section>
      <section id="inscription-guidee" className="public-wrap">
        <ol className="journey-provider-steps" aria-label={copy.eyebrow}>
          {copy.steps.map((step, index) => <li key={step}><span>0{index + 1}</span><CheckCircle2 aria-hidden="true" size={17}/>{step}</li>)}
        </ol>
        <p className="journey-login-note">{copy.note}</p>
        <div className="public-contact-board mt-6">
          <div className="public-card mt-0 max-w-none">
            <h2 className="text-xl">{locale === "ar" ? "تسجيل موجّه" : "Inscription guidée"}</h2>
            <p className="public-muted mt-2">{copy.example}</p>
            <ProviderTaxonomySelector locale={locale} libraries={taxonomy.libraries} />
          </div>
          <aside className="public-card">
            <h2>{copy.whyTitle}</h2>
            <p className="public-muted mt-2">{copy.whyText}</p>
            <ul className="mt-4 space-y-2 text-sm text-slate-700">
              {copy.whyItems.map((item) => <li key={item} className="flex items-start gap-2"><CheckCircle2 aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-[#3d6b55]" />{item}</li>)}
            </ul>
          </aside>
        </div>
      </section>
      <section className="public-wrap mt-10">
        <h2>{locale === "ar" ? "مسار تأهيل واضح وآمن" : "Un processus de qualification clair et sécurisé"}</h2>
        <ol className="public-qualify">
          {(locale === "ar"
            ? [["وصف النشاط", "صرّحوا بنشاطكم واختاروا خدماتكم."], ["تأكيد الخدمات", "راجعوا الخدمات المقترحة."], ["إنشاء الحساب", "بيانات الأساس وتأكيد الهاتف عبر OTP."], ["استكمال الملف", "هوية المؤسسة والوثائق والكفاءات."], ["مراجعة ماتريسيا", "ندرس الملف ونبلغكم بالقرار."]]
            : [["Décrire l’activité", "Renseignez votre activité et sélectionnez vos services."], ["Confirmer les services suggérés", "Vérifiez et ajustez les services proposés."], ["Créer le compte", "Renseignez vos informations de base et confirmez votre téléphone par OTP."], ["Compléter le dossier", "Ajoutez l’identité, les documents, vos compétences et votre capacité d’intervention."], ["Revue Matricia", "Notre équipe vérifie votre dossier et vous informe par e-mail."]]
          ).map(([title, text], index) => (
            <li key={title}><span>{index + 1}</span><strong>{title}</strong><em className="font-normal not-italic text-slate-600">{text}</em></li>
          ))}
        </ol>
      </section>
      <section className="public-wrap journey-cta-band mt-10">
        <div>
          <h2>{locale === "ar" ? "جاهزون للانضمام إلى مجتمع ماتريسيا؟" : "Prêt à rejoindre la communauté Matricia ?"}</h2>
          <p>{locale === "ar" ? "أنشئوا حسابكم الآن وتابعوا تسجيلكم." : "Créez votre compte dès maintenant et poursuivez votre inscription."}</p>
        </div>
        <div className="flex flex-wrap gap-3">
          <a className="journey-primary" href="#inscription-guidee">{copy.begin}</a>
          <Link className="journey-secondary" href={`/${locale}/connexion?next=${encodeURIComponent(`/${locale}/sous-traitant/qualification`)}`}>{copy.existing}</Link>
        </div>
      </section>
    </main>
  );
}
