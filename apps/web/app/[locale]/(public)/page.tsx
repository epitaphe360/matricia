import Link from "next/link";
import { ArrowRight, CheckCircle2, ClipboardCheck, FileSignature, LineChart, ListTree, MessageSquareText, Scale, Settings, ShieldCheck, Sparkles, Target, Users } from "lucide-react";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";

export default async function PublicHomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const c = getPublicJourneyCopy(locale).home;
  const preview = [
    [c.responseLabel, c.exampleProblem, MessageSquareText],
    [c.priorityLabel, c.exampleTitle, Target],
    [c.actionLabel, c.exampleAction, ClipboardCheck],
  ] as const;
  const stepIcons = [Target, ListTree, Users, Scale, FileSignature, Settings, LineChart] as const;
  const trust = (
    <ul className="journey-trust">
      {c.trust.map((item) => (
        <li key={item}><ShieldCheck size={16} aria-hidden="true" />{item}</li>
      ))}
    </ul>
  );

  return (
    <main id="contenu-principal" className="journey-home">
      <section className="journey-home-hero" data-locale={locale}>
        <div className="journey-hero-copy">
          <p className="journey-eyebrow">{c.eyebrow}</p>
          <h1>{c.title}</h1>
          <p className="journey-lead">{c.intro}</p>
          <div className="journey-actions">
            <Link className="journey-primary is-coral" href={`/${locale}/diagnostic`}>
              {c.start}
              <ArrowRight className="rtl-mirror" size={18} aria-hidden="true" />
            </Link>
            <Link className="journey-secondary" href={`/${locale}/fournisseur`}>
              {c.provider}
            </Link>
            <Link className="journey-known" href={`/${locale}/besoin`}>
              {c.known}
              <ArrowRight className="rtl-mirror" size={16} aria-hidden="true" />
            </Link>
          </div>
          {locale === "fr" ? trust : null}
        </div>
        {locale === "ar" ? (
          <PublicPhoto scene="window" caption="مقاولات أكثر وضوحاً لمغرب أقوى" />
        ) : (
          <aside className="journey-preview" aria-label={c.example}>
            <p className="journey-preview-label">{c.example}</p>
            <div className="journey-preview-flow">
              {preview.map(([label, text, Icon]) => (
                <div className="journey-preview-step" key={label}>
                  <div className="journey-preview-card">
                    <span>
                      <Icon aria-hidden="true" size={18} />
                      {label}
                    </span>
                    <strong>{text}</strong>
                    {label === c.actionLabel ? <p>{c.exampleCta}</p> : null}
                  </div>
                </div>
              ))}
            </div>
            <PublicPhoto className="mt-4 min-h-[180px]" scene="arch" caption="Des talents pour demain" />
          </aside>
        )}
      </section>

      <section id="comment-ca-marche" className="journey-home-section">
        <p className="journey-eyebrow">{c.stepsEyebrow}</p>
        <h2 className="journey-value-title">{c.stepsTitle}</h2>
        <ol className="journey-steps">
          {c.steps.map(([title, text], index) => {
            const Icon = stepIcons[index] ?? Target;
            return (
              <li key={title}>
                <span><Icon size={16} aria-hidden="true" /></span>
                <strong>{index + 1}. {title}</strong>
                <p>{text}</p>
              </li>
            );
          })}
        </ol>
        {locale === "ar" ? trust : null}
      </section>

      <section className="journey-home-section">
        <p className="journey-eyebrow">{c.outcomesEyebrow}</p>
        <h2 className="journey-value-title">{c.outcomesTitle}</h2>
        <div className="journey-outcomes">
          {c.outcomes.map(([title, text]) => (
            <article key={title}>
              <Sparkles aria-hidden="true" className="text-[#6d3cc7]" size={22} />
              <h3>{title}</h3>
              <p>{text}</p>
            </article>
          ))}
        </div>
      </section>

      <section id="professionnels" className="journey-home-provider">
        <p className="journey-eyebrow">{c.provider}</p>
        <h2>{c.providerTitle}</h2>
        <p>{c.providerText}</p>
        <Link className="journey-primary" href={`/${locale}/fournisseur`}>
          {c.providerAction}
          <ArrowRight className="rtl-mirror" size={18} aria-hidden="true" />
        </Link>
      </section>

      <section className="journey-home-section">
        <p className="journey-eyebrow">{c.faqEyebrow}</p>
        <h2 className="journey-value-title">{c.faqTitle}</h2>
        <div className="journey-faq">
          {c.faqs.map(([question, answer]) => (
            <details key={question}>
              <summary>
                {question}
                <CheckCircle2 aria-hidden="true" size={18} />
              </summary>
              <p>{answer}</p>
            </details>
          ))}
        </div>
        <div className="journey-cta-band">
          <div>
            <h2>{c.ctaTitle}</h2>
            <p>{c.ctaText}</p>
          </div>
          <Link className="journey-primary" href={`/${locale}/diagnostic`}>
            {c.start}
            <ArrowRight className="rtl-mirror" size={18} aria-hidden="true" />
          </Link>
        </div>
      </section>
    </main>
  );
}
