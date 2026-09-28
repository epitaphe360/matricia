import Image from "next/image";
import Link from "next/link";
import {
  ArrowUpRight,
  BadgeCheck,
  BarChart3,
  BriefcaseBusiness,
  Check,
  ChevronDown,
  ClipboardCheck,
  FileCheck2,
  GitCompareArrows,
  Route,
  SearchCheck,
  ShieldCheck,
  Sparkles,
  Target,
  Users,
} from "lucide-react";
import { getHomePremiumCopy, type HomeLocale } from "./home-premium.copy";
import styles from "./home-premium.module.css";

type HomePremiumProps = {
  locale: HomeLocale;
};

const cycleIcons = [SearchCheck, Route, Users, GitCompareArrows, FileCheck2, BriefcaseBusiness, BarChart3] as const;
const outcomeIcons = [Target, ClipboardCheck, GitCompareArrows, ShieldCheck] as const;

export function HomePremium({ locale }: HomePremiumProps) {
  const copy = getHomePremiumCopy(locale);
  const href = (path: string) => `/${locale}${path}`;

  return (
    <main id="contenu-principal" className={styles.page} dir={locale === "ar" ? "rtl" : "ltr"}>
      <section className={styles.hero} aria-labelledby="home-title">
        <div className={styles.heroGlow} aria-hidden="true" />
        <div className={styles.heroCopy}>
          <p className={styles.eyebrow}><Sparkles size={16} aria-hidden="true" />{copy.eyebrow}</p>
          <h1 id="home-title">
            {copy.titleLead} <span>{copy.titleAccent}</span>
          </h1>
          <p className={styles.lead}>{copy.intro}</p>

          <div className={styles.heroActions}>
            <Link className={styles.primaryButton} href={href("/diagnostic")}>
              {copy.primaryAction}<ArrowUpRight size={19} aria-hidden="true" />
            </Link>
            <Link className={styles.secondaryButton} href={href("/fournisseur")}>
              {copy.providerAction}
            </Link>
          </div>

          <Link className={styles.textLink} href={href("/besoin")}>
            {copy.preciseNeedAction}<ArrowUpRight size={16} aria-hidden="true" />
          </Link>
        </div>

        <div className={styles.heroVisual} aria-label={copy.previewLabel}>
          <div className={styles.photoFrame}>
            <Image
              className={styles.heroPhoto}
              src="/home-v2/hero-collaboration.png"
              alt=""
              fill
              priority
              sizes="(max-width: 900px) 100vw, 48vw"
            />
            <div className={styles.photoShade} aria-hidden="true" />
            <div className={styles.projectCard}>
              <span>{copy.projectLabel}</span>
              <strong>{copy.projectTitle}</strong>
              <small><span className={styles.liveDot} />{copy.projectStatus}</small>
            </div>
            <div className={styles.offerCard}>
              <BadgeCheck size={20} aria-hidden="true" />
              <div><span>{copy.offersLabel}</span><strong>{copy.offersValue}</strong></div>
            </div>
            <div className={styles.decisionCard}>
              <Target size={20} aria-hidden="true" />
              <div><span>{copy.decisionLabel}</span><strong>{copy.decisionValue}</strong></div>
            </div>
          </div>

          <ol className={styles.progress} aria-label={copy.previewLabel}>
            {copy.previewStages.map((stage, index) => (
              <li key={stage} className={index < 2 ? styles.progressActive : undefined}>
                <span>{index === 0 ? <Check size={13} aria-hidden="true" /> : index + 1}</span>
                {stage}
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className={styles.cycleSection} aria-labelledby="cycle-title">
        <div className={styles.sectionHeading}>
          <div>
            <p className={styles.sectionEyebrow}>{copy.cycleEyebrow}</p>
            <h2 id="cycle-title">{copy.cycleTitle}</h2>
          </div>
          <p>{copy.cycleIntro}</p>
        </div>
        <ol className={styles.cycleGrid}>
          {copy.cycle.map((step, index) => {
            const Icon = cycleIcons[index];
            return (
              <li key={step.label}>
                <span className={styles.stepNumber}>{String(index + 1).padStart(2, "0")}</span>
                <span className={styles.cycleIcon}><Icon size={21} aria-hidden="true" /></span>
                <strong>{step.label}</strong>
                <small>{step.description}</small>
              </li>
            );
          })}
        </ol>
      </section>

      <section className={styles.valueSection} aria-labelledby="outcomes-title">
        <div className={styles.valueIntro}>
          <p className={styles.sectionEyebrow}>{copy.outcomesEyebrow}</p>
          <h2 id="outcomes-title">{copy.outcomesTitle}</h2>
          <p>{copy.outcomesIntro}</p>
          <div className={styles.signalLine} aria-hidden="true"><i /><i /><i /><i /></div>
        </div>
        <div className={styles.outcomeGrid}>
          {copy.outcomes.map((outcome, index) => {
            const Icon = outcomeIcons[index];
            return (
              <article key={outcome.title}>
                <span><Icon size={22} aria-hidden="true" /></span>
                <h3>{outcome.title}</h3>
                <p>{outcome.description}</p>
              </article>
            );
          })}
        </div>
      </section>

      <section className={styles.professionalSection} aria-labelledby="professional-title">
        <div className={styles.professionalVisual} aria-hidden="true">
          <div className={styles.orbit}><Users size={34} /></div>
          <div className={styles.orbitBadge}><ShieldCheck size={20} />{copy.qualificationBadge}</div>
        </div>
        <div className={styles.professionalCopy}>
          <p className={styles.sectionEyebrow}>{copy.professionalsEyebrow}</p>
          <h2 id="professional-title">{copy.professionalsTitle}</h2>
          <p>{copy.professionalsIntro}</p>
          <ul>
            {copy.professionals.map((item) => <li key={item}><Check size={17} aria-hidden="true" />{item}</li>)}
          </ul>
          <Link className={styles.darkLink} href={href("/fournisseur")}>
            {copy.professionalsAction}<ArrowUpRight size={18} aria-hidden="true" />
          </Link>
        </div>
      </section>

      <section className={styles.faqSection} aria-labelledby="faq-title">
        <div>
          <p className={styles.sectionEyebrow}>{copy.faqEyebrow}</p>
          <h2 id="faq-title">{copy.faqTitle}</h2>
        </div>
        <div className={styles.faqList}>
          {copy.faq.map((item, index) => (
            <details key={item.question} open={index === 0}>
              <summary>{item.question}<ChevronDown size={19} aria-hidden="true" /></summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <section className={styles.finalCta} aria-labelledby="final-title">
        <div className={styles.finalGlow} aria-hidden="true" />
        <p className={styles.eyebrow}><Sparkles size={16} aria-hidden="true" />Matricia</p>
        <h2 id="final-title">{copy.finalTitle}</h2>
        <p>{copy.finalIntro}</p>
        <div>
          <Link className={styles.lightButton} href={href("/diagnostic")}>
            {copy.finalPrimary}<ArrowUpRight size={18} aria-hidden="true" />
          </Link>
          <Link className={styles.ghostButton} href={href("/besoin")}>{copy.finalSecondary}</Link>
        </div>
      </section>
    </main>
  );
}
