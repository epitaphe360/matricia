import Link from "next/link";
import { ArrowRight, CheckCircle2, ClipboardCheck, FileSignature, LineChart, ListTree, Scale, Settings, ShieldCheck, Sparkles, Target, Users } from "lucide-react";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";
import { PublicRibbon } from "@/modules/public/ui/site/public-art";

function splitTitle(title: string) {
  const index = title.indexOf(". ");
  if (index < 0) return { lead: title, rest: "" };
  return { lead: title.slice(0, index + 1), rest: title.slice(index + 2) };
}

export default async function PublicHomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const c = getPublicJourneyCopy(locale).home;
  const title = splitTitle(c.title);
  const stepIcons = [Target, ListTree, Users, Scale, FileSignature, Settings, LineChart] as const;
  const outcomeIcons = [CheckCircle2, ClipboardCheck, Sparkles, ShieldCheck] as const;
  const trustIcons = [Target, Users, ShieldCheck, LineChart] as const;
  const trustItems = locale === "ar" ? c.trust : c.trust.slice(0, 3);
  const trust = (
    <ul className="journey-trust">
      {trustItems.map((item, index) => {
        const Icon = trustIcons[index] ?? ShieldCheck;
        return <li key={item}><Icon size={16} aria-hidden="true" />{item}</li>;
      })}
    </ul>
  );

  return (
    <main id="contenu-principal" className="journey-home">
      <section className="journey-home-hero" data-locale={locale}>
        <div className="journey-hero-copy">
          <p className="journey-eyebrow">{c.eyebrow}</p>
          <h1>{title.lead}{title.rest ? <> <em>{title.rest}</em></> : null}</h1>
          <p className="journey-lead">{c.intro}</p>
          {locale === "ar" ? <p className="journey-ar-side-note" aria-hidden="true">خيارات مغربية لأثر حقيقي</p> : null}
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
          <PublicPhoto className="journey-ar-hero-photo" scene="window" caption="مقاولات أكثر وضوحاً لمغرب أقوى" />
        ) : (
          <aside className="journey-preview" aria-label={c.example}>
            <p className="journey-script journey-script-float">{c.scriptNote}</p>
            <div className="journey-preview-stage">
              <div className="journey-preview-flow">
                <div className="journey-preview-step">
                  <div className="journey-preview-card">
                    <span>{c.responseLabel}</span>
                    <strong>{c.exampleProblem}</strong>
                    <ul className="journey-preview-options" aria-hidden="true">
                      {c.exampleOptions.map((option) => (
                        <li key={option} className={option === c.exampleSelected ? "is-selected" : undefined}>{option}</li>
                      ))}
                    </ul>
                  </div>
                </div>
                <div className="journey-preview-step">
                  <div className="journey-preview-card">
                    <span>{c.priorityLabel}</span>
                    <Target aria-hidden="true" className="journey-preview-icon" size={28} />
                    <strong>{c.exampleTitle}</strong>
                    <p>{c.examplePriorityText}</p>
                  </div>
                </div>
                <div className="journey-preview-step">
                  <div className="journey-preview-card">
                    <span>{c.actionLabel}</span>
                    <PublicPhoto className="journey-preview-portrait" scene="craftsman" caption="" />
                    <strong>{c.exampleAction}</strong>
                    <ul className="journey-preview-tags">
                      {c.exampleTags.map((tag) => <li key={tag}>{tag}</li>)}
                    </ul>
                    <Link className="journey-known" href={`/${locale}/diagnostic`}>{c.exampleCta}<ArrowRight className="rtl-mirror" size={14} aria-hidden="true" /></Link>
                    <p>{c.example}</p>
                  </div>
                </div>
              </div>
              <PublicPhoto className="journey-preview-photo" scene="arch" caption={c.previewPhoto} />
            </div>
          </aside>
        )}
      </section>

      <section id="comment-ca-marche" className="journey-home-section">
        <div className="journey-section-heading">
          <div>
            <h2 className="journey-value-title">{c.stepsTitle}</h2>
            <p className="journey-eyebrow">{c.stepsEyebrow}</p>
          </div>
          {locale === "fr" ? <p className="journey-script journey-script-inline">{c.trust[3]}</p> : null}
        </div>
        <ol className="journey-steps">
          {c.steps.map(([stepTitle, text], index) => {
            const Icon = stepIcons[index] ?? Target;
            return (
              <li key={stepTitle}>
                <span>{locale === "ar" ? index + 1 : <Icon size={18} aria-hidden="true" />}</span>
                <strong>{stepTitle}</strong>
                <p>{text}</p>
              </li>
            );
          })}
        </ol>
        {locale === "ar" ? trust : null}
      </section>

      {locale === "fr" ? (
      <>
      <section className="journey-home-section journey-outcomes-board">
        <div>
          <p className="journey-eyebrow">{c.outcomesEyebrow}</p>
          <h2 className="journey-value-title">{c.outcomesTitle}</h2>
          <div className="journey-outcomes">
            {c.outcomes.map(([stepTitle, text], index) => {
              const Icon = outcomeIcons[index] ?? Sparkles;
              return (
                <article key={stepTitle} data-tone={index}>
                  <Icon aria-hidden="true" size={22} />
                  <h3>{stepTitle}</h3>
                  <p>{text}</p>
                </article>
              );
            })}
          </div>
        </div>
        <aside className="journey-home-provider" id="professionnels">
          <PublicRibbon />
          <p className="journey-eyebrow">Des professionnels de confiance</p>
          <h2>{c.providerTitle}</h2>
          <p>{c.providerText}</p>
          <Link className="journey-known" href={`/${locale}/fournisseur`}>
            {c.providerAction}
            <ArrowRight className="rtl-mirror" size={16} aria-hidden="true" />
          </Link>
        </aside>
      </section>

      <section className="journey-home-section journey-faq-board">
        <div>
          <p className="journey-eyebrow">{c.faqEyebrow}</p>
          <h2 className="journey-value-title">{c.faqTitle}</h2>
          <div className="journey-faq">
            {c.faqs.map(([question, answer]) => (
              <details key={question}>
                <summary>
                  {question}
                  <span aria-hidden="true">+</span>
                </summary>
                <p>{answer}</p>
              </details>
            ))}
          </div>
        </div>
        <div className="journey-cta-band is-accent">
          <div>
            <p className="journey-eyebrow">Passons aux bonnes solutions</p>
            <h2>{c.ctaTitle}</h2>
            <p>{c.ctaText}</p>
            <Link className="journey-primary" href={`/${locale}/diagnostic`}>
              {c.start}
              <ArrowRight className="rtl-mirror" size={18} aria-hidden="true" />
            </Link>
          </div>
          <PublicPhoto className="journey-cta-photo" scene="terrace" caption={c.ctaCaption} />
        </div>
      </section>
      </>
      ) : null}
    </main>
  );
}
