import { randomUUID } from "node:crypto";
import type { ReactNode } from "react";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { ArrowRight, BookmarkPlus, Pencil, Target, UserPlus } from "lucide-react";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { SolutionDecisionAccess } from "@/modules/client/screens/diagnostics/solutions/decision-access";
import { messages } from "@/modules/client/screens/diagnostics/solutions/messages";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { formatMinorExact, formatScoreBps, narrativeText } from "@/modules/shared/lib/solution-insights/model";
import { createServerSolutionInsightsRepository } from "@/modules/shared/lib/solution-insights/server-repository";
import "@/modules/client/screens/diagnostics/diagnostic-connected.css";

export default async function SolutionsPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string; anomalyId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/client/diagnostics/solutions` }));
  const m = messages(locale);
  const result = await (await createServerSolutionInsightsRepository()).list();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/client/diagnostics/solutions` }));
  const shell = (title: string | undefined, lead: string | undefined, children: ReactNode) => (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="needs" title={title} lead={lead} kicker={spaceCopy(locale).kicker}>{children}</ClientAppShell>
  );
  if (result.status === "error" && result.reason === "FORBIDDEN") {
    return shell(m.forbidden, m.forbidden, <main className="client-page" role="alert"><p>{m.forbidden}</p></main>);
  }
  if (result.status === "error") {
    return shell(m.title, m.intro, <main className="client-page" role="alert"><p className="client-card">{locale === "ar" ? "تعذر تحميل الحلول." : "Impossible de charger les solutions."}</p></main>);
  }
  const focused = query.anomalyId ? result.value.sets.filter((set) => set.anomalyId === query.anomalyId) : [];
  const orderedSets = focused.length ? [...focused, ...result.value.sets.filter((set) => set.anomalyId !== query.anomalyId)] : result.value.sets;
  const diagnosticHref = `/${locale}/client/diagnostics${space.selectedQuery}`;
  const assistanceHref = `/${locale}/client/diagnostics/assistance${space.selectedQuery}`;
  const needHref = `/${locale}/besoin${space.selectedQuery}`;
  const t = locale === "fr"
    ? {
        crumb: "Mes diagnostics > Solutions adaptées",
        title: "Solutions adaptées à vos priorités",
        lead: "Des solutions concrètes sélectionnées selon votre diagnostic confirmé.",
        quote: "Des solutions concrètes pour une entreprise marocaine qui avance.",
        priority: "Priorité sélectionnée",
        seeDiag: "Voir mon diagnostic",
        context: "Votre contexte confirmé",
        edit: "Modifier",
        next: "Un expert pourra affiner ces options avec vous avant toute consultation.",
        describe: "Décrire mon besoin",
        review: "Demander une revue humaine",
        save: "Enregistrer pour plus tard",
        why: "Pourquoi cela correspond",
        deliverables: "Livrables attendus",
        prereq: "Prérequis",
        horizon: "Horizon typique",
        criteria: "Critères de qualification",
        compatible: "Très compatible",
      }
    : {
        crumb: "تشخيصاتي > حلول مناسبة",
        title: "حلول مناسبة لأولوياتكم",
        lead: "حلول ملموسة مختارة وفق تشخيصكم المؤكد.",
        quote: "حلول ملموسة لمؤسسة مغربية تتقدم.",
        priority: "الأولوية المختارة",
        seeDiag: "عرض تشخيصي",
        context: "سياقكم المؤكد",
        edit: "تعديل",
        next: "يمكن لخبير تدقيق هذه الخيارات معكم قبل أي استشارة.",
        describe: "وصف احتياجي",
        review: "طلب مراجعة بشرية",
        save: "الحفظ للاحقاً",
        why: "لماذا يناسب ذلك",
        deliverables: "المخرجات المتوقعة",
        prereq: "المتطلبات",
        horizon: "الأفق النموذجي",
        criteria: "معايير التأهيل",
        compatible: "توافق عالٍ",
      };

  return shell(undefined, undefined, (
    <main className="client-page">
      <div className="diag-conn">
        <header className="diag-conn-hero">
          <div>
            <p className="diag-conn-crumb">{t.crumb}</p>
            <h1>{t.title}</h1>
            <p>{t.lead}</p>
          </div>
          <p className="diag-conn-quote">« {t.quote} »</p>
        </header>

        <div className="diag-conn-card" style={{ display: "flex", flexWrap: "wrap", gap: 12, alignItems: "center", justifyContent: "space-between" }}>
          <p><Target size={16} style={{ display: "inline", verticalAlign: "middle" }} aria-hidden /> {t.priority} : <strong>{m.title}</strong></p>
          <Link href={diagnosticHref} style={{ color: "var(--diag-violet)", fontWeight: 720 }}>{t.seeDiag} →</Link>
        </div>

        <div className="diag-conn-split">
          <div className="diag-conn-stack">
            <div className="diag-conn-filter" aria-hidden="true">
              <select aria-label="Objectif"><option>{locale === "fr" ? "Tous les objectifs" : "كل الأهداف"}</option></select>
              <select aria-label="Horizon"><option>{locale === "fr" ? "Tous les horizons" : "كل الآفاق"}</option></select>
              <select aria-label="Taille"><option>{locale === "fr" ? "Toutes les tailles" : "كل الأحجام"}</option></select>
              <select aria-label="Localisation"><option>{locale === "fr" ? "Toutes les régions" : "كل الجهات"}</option></select>
              <button type="button">{locale === "fr" ? "Réinitialiser les filtres" : "إعادة ضبط المرشحات"}</button>
            </div>

            {orderedSets.length === 0 ? <p className="diag-conn-card">{m.empty}</p> : orderedSets.map((set) => (
              <article key={set.id} className="diag-conn-sol-card">
                <div className="diag-conn-item-foot">
                  <h2 style={{ fontSize: "1.1rem" }}>{locale === "ar" ? set.rationaleAr : set.rationaleFr}</h2>
                  <span className="diag-conn-badge" data-tone="mint">{t.compatible}</span>
                </div>
                <div className="diag-conn-sol-grid">
                  {set.options.map((option) => (
                    <div key={option.id}>
                      <h3>{m.levels[option.level]}</h3>
                      <ul>
                        <li>{t.why}: {narrativeText(Object.values(option.explanation)[0] ?? m.rationale, locale)}</li>
                        <li>{t.deliverables}: {option.benefits.slice(0, 2).map((item) => narrativeText(item, locale)).join(" · ") || "—"}</li>
                        <li>{t.prereq}: {option.tradeoffs.slice(0, 1).map((item) => narrativeText(item, locale)).join(" · ") || "—"}</li>
                        <li>{t.horizon}: <span dir="ltr">{formatScoreBps(option.expectedScoreBps, locale)}</span></li>
                        <li>{m.amount}: <span dir="ltr">{option.estimatedAmountMinor && option.currency ? formatMinorExact(option.estimatedAmountMinor, option.currency, locale) : m.unavailable}</span></li>
                      </ul>
                      <div style={{ marginTop: 10 }}>
                        <SolutionDecisionAccess canDecide={set.canDecide} locale={locale} solutionSetId={set.id} level={option.level} idempotencyKey={randomUUID()} messages={m} />
                      </div>
                    </div>
                  ))}
                </div>
              </article>
            ))}
          </div>

          <aside className="diag-conn-stack">
            <section className="diag-conn-context">
              <div className="diag-conn-item-foot">
                <h2 style={{ fontSize: "1rem" }}>{t.context}</h2>
                <Link href={diagnosticHref} style={{ color: "var(--diag-violet)", fontWeight: 700 }}><Pencil size={14} aria-hidden /> {t.edit}</Link>
              </div>
              <dl>
                <div><dt>{t.priority}</dt><dd>{m.title}</dd></div>
                <div><dt>{locale === "fr" ? "Organisation" : "المؤسسة"}</dt><dd>{space.organizationName ?? "—"}</dd></div>
              </dl>
            </section>
            <div className="diag-conn-callout" data-tone="amber">
              <Target size={16} aria-hidden />
              <p>{t.next} <Link href={assistanceHref} style={{ fontWeight: 720 }}>{locale === "fr" ? "En savoir plus →" : "معرفة المزيد ←"}</Link></p>
            </div>
            <div className="diag-conn-stack">
              <Link href={needHref} className="diag-conn-btn-grad">{t.describe}<ArrowRight className="rtl-mirror" size={16} aria-hidden /></Link>
              <Link href={assistanceHref} className="diag-conn-btn-outline"><UserPlus size={15} aria-hidden />{t.review}</Link>
              <Link href={diagnosticHref} className="diag-conn-btn-outline"><BookmarkPlus size={15} aria-hidden />{t.save}</Link>
            </div>
          </aside>
        </div>
      </div>
    </main>
  ));
}
