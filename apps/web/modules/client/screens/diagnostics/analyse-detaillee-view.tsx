import Link from "next/link";
import { AlertTriangle, ArrowRight, CheckCircle2, Download, Lightbulb, Share2, Sparkles, Target } from "lucide-react";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { formatExactScore, type DiagnosticDetail } from "@/modules/shared/lib/diagnostics-opportunities/model";
import { formatDimensionKey, labelSolutionLevel } from "./journey";
import type { Messages } from "./messages";
import { OpportunityActions } from "./opportunity-actions";
import { OpportunityContext } from "./diagnostic-snapshot";
import "./diagnostic-connected.css";

type Props = {
  detail: DiagnosticDetail;
  locale: Locale;
  m: Messages;
  solutionsHref: string;
  assistanceHref: string;
  evolutionHref: string;
  listHref: string;
  anomalyId?: string;
  decisionKeys: string[];
};

export function AnalyseDetailleeView({ detail, locale, m, solutionsHref, assistanceHref, evolutionHref, listHref, anomalyId, decisionKeys }: Props) {
  const pct = Math.max(0, Math.min(100, Number(formatExactScore(detail.score))));
  const findings = detail.anomalies;
  const strengths = findings.filter((item) => item.severity === "LOW" || item.status === "RESOLVED").slice(0, 3);
  const anomalies = findings.filter((item) => item.severity !== "LOW").slice(0, 6);
  const opportunities = detail.opportunities.filter((item) => item.status !== "CLOSED").slice(0, 6);
  const plan = detail.recommendations.slice(0, 4);
  const focused = anomalyId ? findings.find((item) => item.id === anomalyId) : null;
  const focusedRecs = focused ? detail.recommendations.filter((item) => item.anomalyId === focused.id) : [];
  const focusedOpp = focused ? detail.opportunities.find((item) => item.anomalyId === focused.id) : null;
  const t = locale === "fr"
    ? {
        crumb: "Bilan & besoins > Analyse détaillée",
        title: "Analyse détaillée",
        lead: "Votre diagnostic complet pour identifier vos priorités et passer à l’action.",
        quote: "Des diagnostics clairs, des décisions plus sereines.",
        validated: "Validé",
        scope: "Périmètre",
        date: "Date d’analyse",
        method: "Méthodologie",
        understand: "Comprendre le calcul",
        mastery: detail.rating === "GOOD" ? "Bonne maîtrise" : detail.rating === "ATTENTION" ? "Maîtrise intermédiaire" : detail.rating === "IMPORTANT" ? "Points importants" : "Situation critique",
        scoreNote: "Ce score est basé sur vos réponses confirmées et sur les règles de la méthode versionnée.",
        dims: "Vos scores par dimension",
        synth: "Synthèse",
        details: "Détails",
        answers: "Réponses",
        methodTab: "Méthodologie",
        history: "Historique",
        download: "Télécharger le rapport",
        share: "Partager avec un conseiller",
        constats: "Constats",
        constatsLead: "Ce qui fonctionne bien dans votre organisation.",
        anomaliesTitle: "Anomalies à vérifier",
        anomaliesLead: "Des points d’attention qui méritent une analyse approfondie.",
        opps: "Opportunités",
        oppsLead: "Des leviers concrets pour accélérer votre développement.",
        planTitle: "Plan d’action recommandé",
        planLead: "Nos recommandations, priorisées selon votre contexte.",
        act: "Passer à l’action",
        seeExplain: "Voir l’explication",
        proofs: "preuves",
        decision: "Votre décision",
        decisionLead: "Une validation humaine reste nécessaire avant toute suite engageante.",
        decisionWarn: "Prenez le temps de relire les informations ci-contre avant de confirmer ce constat.",
        confirm: "Confirmer le constat",
        correct: "Corriger mes réponses",
        review: "Demander une revue humaine",
        reco: "Notre recommandation",
        createOpp: "Créer une opportunité",
        seeSolutions: "Voir les solutions adaptées",
        help: "Besoin d’accompagnement ? Échangez avec un expert Matricia.",
        back: "Retour aux diagnostics",
        confidenceHigh: "Confiance élevée",
        confidenceMid: "Confiance moyenne",
        priorityHigh: "Priorité haute",
        priorityMid: "Priorité moyenne",
        observed: "Ce que l’analyse a observé",
        why: "Pourquoi cela compte",
        how: "Comment le résultat a été calculé",
        missing: "Informations encore nécessaires",
      }
    : {
        crumb: "التشخيص والاحتياجات > تحليل مفصل",
        title: "تحليل مفصل",
        lead: "تشخيصكم الكامل لتحديد الأولويات والانتقال إلى التنفيذ.",
        quote: "تشخيصات واضحة وقرارات أكثر اطمئناناً.",
        validated: "مصادق",
        scope: "النطاق",
        date: "تاريخ التحليل",
        method: "المنهجية",
        understand: "فهم الحساب",
        mastery: m.ratings[detail.rating],
        scoreNote: "هذه النتيجة مبنية على إجاباتكم المؤكدة وقواعد المنهج ذي الإصدار.",
        dims: "نتائجكم حسب البعد",
        synth: "ملخص",
        details: "تفاصيل",
        answers: "إجابات",
        methodTab: "المنهجية",
        history: "السجل",
        download: "تحميل التقرير",
        share: "مشاركة مع مستشار",
        constats: "ملاحظات إيجابية",
        constatsLead: "ما يعمل جيداً في مؤسستكم.",
        anomaliesTitle: "اختلالات للتحقق",
        anomaliesLead: "نقاط انتباه تستحق تحليلاً أعمق.",
        opps: "فرص",
        oppsLead: "روافع ملموسة لتسريع التطور.",
        planTitle: "خطة العمل الموصى بها",
        planLead: "توصياتنا مرتبة حسب سياقكم.",
        act: "الانتقال إلى التنفيذ",
        seeExplain: "عرض التفسير",
        proofs: "أدلة",
        decision: "قراركم",
        decisionLead: "تبقى مصادقة بشرية لازمة قبل أي خطوة ملزمة.",
        decisionWarn: "خذوا وقتاً لمراجعة المعلومات قبل تأكيد هذه الملاحظة.",
        confirm: "تأكيد الملاحظة",
        correct: "تصحيح إجاباتي",
        review: "طلب مراجعة بشرية",
        reco: "توصيتنا",
        createOpp: "إنشاء فرصة",
        seeSolutions: "عرض الحلول المناسبة",
        help: "تحتاجون مرافقة؟ تواصلوا مع خبير ماتريسيا.",
        back: "العودة إلى التشخيصات",
        confidenceHigh: "ثقة مرتفعة",
        confidenceMid: "ثقة متوسطة",
        priorityHigh: "أولوية عالية",
        priorityMid: "أولوية متوسطة",
        observed: "ما لاحظه التحليل",
        why: "لماذا يهم ذلك",
        how: "كيف حُسبت النتيجة",
        missing: "معلومات ما زالت لازمة",
      };

  if (focused) {
    return (
      <div className="diag-conn">
        <header className="diag-conn-hero">
          <div>
            <p className="diag-conn-crumb">{t.crumb}</p>
            <h1>{locale === "ar" ? focused.titleAr : focused.titleFr}</h1>
            <p>{t.decisionLead}</p>
          </div>
          <p className="diag-conn-quote">« {t.quote} »</p>
        </header>
        <div className="diag-conn-split">
          <div className="diag-conn-stack">
            <section className="diag-conn-card">
              <div className="diag-conn-item-foot">
                <span className="diag-conn-badge" data-tone={focused.severity === "CRITICAL" || focused.severity === "HIGH" ? "coral" : "amber"}>
                  {focused.severity}{focused.blocking ? ` · ${m.blocking}` : ""}
                </span>
                <time dateTime={detail.completedAt}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(detail.completedAt))}</time>
              </div>
              <h2 style={{ marginTop: 12 }}>{locale === "ar" ? focused.titleAr : focused.titleFr}</h2>
            </section>
            <section className="diag-conn-card">
              <h2><CheckCircle2 size={18} color="#1f6b4a" aria-hidden />{t.observed}</h2>
              <p style={{ marginTop: 10, color: "var(--diag-muted)" }}>{String(focused.explanation.summary ?? focused.explanation.reason ?? m.explanation)}</p>
            </section>
            <section className="diag-conn-card">
              <h2><Lightbulb size={18} color="#6f46e8" aria-hidden />{t.why}</h2>
              <p style={{ marginTop: 10, color: "var(--diag-muted)" }}>{String(focused.explanation.impact ?? focused.explanation.why ?? m.whyOpportunity)}</p>
            </section>
            <section className="diag-conn-card">
              <h2><Target size={18} color="#1d4ed8" aria-hidden />{t.how}</h2>
              <p style={{ marginTop: 10, color: "var(--diag-muted)" }}>{m.policyVersion}: {String(detail.scoringPolicySnapshot.version ?? "—")}</p>
              <p style={{ marginTop: 6, color: "var(--diag-muted)" }}>{m.ruleSnapshot}: {String(focused.ruleSnapshot.code ?? focused.code)}</p>
            </section>
            {focusedOpp ? (
              <section className="diag-conn-card">
                <h2>{m.opportunities}</h2>
                <div style={{ marginTop: 12 }}>
                  <OpportunityContext opportunity={focusedOpp} detail={detail} locale={locale} m={m} />
                  <OpportunityActions locale={locale} runId={detail.id} o={focusedOpp} m={m} keys={decisionKeys} />
                </div>
              </section>
            ) : null}
          </div>
          <aside className="diag-conn-stack">
            <section className="diag-conn-card">
              <h2>{t.decision}</h2>
              <p style={{ marginTop: 8, color: "var(--diag-muted)" }}>{t.decisionLead}</p>
              <div className="diag-conn-callout" data-tone="amber" style={{ marginTop: 12 }}>
                <AlertTriangle size={16} aria-hidden />
                <p>{t.decisionWarn}</p>
              </div>
              <div className="diag-conn-stack" style={{ marginTop: 14 }}>
                <Link href={solutionsHref} className="diag-conn-btn"><CheckCircle2 size={16} aria-hidden />{t.confirm}</Link>
                <Link href={`/${locale}/client/questionnaires`} className="diag-conn-btn-outline">{t.correct}</Link>
                <Link href={assistanceHref} className="diag-conn-btn-outline">{t.review}</Link>
              </div>
            </section>
            <section className="diag-conn-card">
              <h2>{t.reco}</h2>
              <ol className="diag-conn-plan" style={{ marginTop: 12 }}>
                {(focusedRecs.length ? focusedRecs : plan).slice(0, 3).map((item, index) => (
                  <li key={item.id}>
                    <span>{index + 1}</span>
                    <div>
                      <strong>{locale === "ar" ? item.titleAr : item.titleFr}</strong>
                      <small>{labelSolutionLevel(locale, item.solutionLevel)} · {m.priority} {item.priority}</small>
                    </div>
                  </li>
                ))}
              </ol>
              <div className="diag-conn-stack" style={{ marginTop: 14 }}>
                <Link href={solutionsHref} className="diag-conn-btn-grad">{t.createOpp}<ArrowRight className="rtl-mirror" size={16} aria-hidden /></Link>
                <Link href={solutionsHref} className="diag-conn-btn-outline">{t.seeSolutions}</Link>
              </div>
            </section>
          </aside>
        </div>
        <p className="diag-conn-footer-help"><span>{t.help}</span><Link href={listHref}>{t.back}</Link></p>
      </div>
    );
  }

  return (
    <div className="diag-conn">
      <header className="diag-conn-hero">
        <div>
          <p className="diag-conn-crumb">{t.crumb}</p>
          <h1>{t.title}</h1>
          <p>{t.lead}</p>
        </div>
        <p className="diag-conn-quote">« {t.quote} »</p>
      </header>

      <section className="diag-conn-score" style={{ ["--pct" as string]: pct }}>
        <div className="diag-conn-donut" aria-label={`${m.score} ${formatExactScore(detail.score)}/100`}>
          <span dir="ltr">{formatExactScore(detail.score)} / 100</span>
        </div>
        <div>
          <div className="diag-conn-item-foot">
            <h2>{locale === "fr" ? "Diagnostic organisationnel" : "تشخيص تنظيمي"}</h2>
            <span className="diag-conn-badge" data-tone="mint"><CheckCircle2 size={12} aria-hidden />{t.validated}</span>
          </div>
          <strong style={{ display: "block", marginTop: 8 }}>{t.mastery}</strong>
          <p style={{ marginTop: 6, color: "var(--diag-muted)", fontSize: "0.9rem" }}>{t.scoreNote}</p>
          <div className="diag-conn-meta">
            <div><small>{t.scope}</small><strong>{m.library}</strong></div>
            <div><small>{t.date}</small><strong><time dateTime={detail.completedAt}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(detail.completedAt))}</time></strong></div>
            <div><small>{t.method}</small><strong>{String(detail.scoringPolicySnapshot.version ?? "—")} · <Link href={evolutionHref} style={{ color: "var(--diag-violet)" }}>{t.understand}</Link></strong></div>
          </div>
        </div>
        <div className="diag-conn-dims" aria-label={t.dims}>
          {detail.subscores.slice(0, 6).map((item) => {
            const value = Math.max(0, Math.min(100, Number(formatExactScore(item.score))));
            return (
              <div key={item.key} className="diag-conn-dim">
                <div className="diag-conn-item-foot"><span>{formatDimensionKey(item.key)}</span><strong dir="ltr">{formatExactScore(item.score)}</strong></div>
                <span><i style={{ width: `${value}%` }} /></span>
              </div>
            );
          })}
        </div>
      </section>

      <div className="diag-conn-tabs">
        <nav aria-label={t.synth}>
          <span className="is-active">{t.synth}</span>
          <span>{t.details}</span>
          <span>{t.answers}</span>
          <span>{t.methodTab}</span>
          <Link href={evolutionHref}>{t.history}</Link>
        </nav>
        <div className="diag-conn-actions">
          <button type="button" className="diag-conn-btn-outline"><Download size={15} aria-hidden />{t.download}</button>
          <Link href={assistanceHref} className="diag-conn-btn"><Share2 size={15} aria-hidden />{t.share}</Link>
        </div>
      </div>

      <div className="diag-conn-grid4">
        <section className="diag-conn-col">
          <header className="diag-conn-col-head" data-tone="mint">
            <h2><Sparkles size={16} aria-hidden />{t.constats}<span className="diag-conn-count">{Math.max(strengths.length, findings.length ? 1 : 0)}</span></h2>
            <p>{t.constatsLead}</p>
          </header>
          {(strengths.length ? strengths : findings.slice(0, 1)).map((item) => (
            <article key={item.id} className="diag-conn-item">
              <h3>{locale === "ar" ? item.titleAr : item.titleFr}</h3>
              <span className="diag-conn-badge" data-tone="mint">{t.confidenceHigh}</span>
              <p>{String(item.explanation.summary ?? item.explanation.reason ?? "")}</p>
              <div className="diag-conn-item-foot">
                <small>3 {t.proofs}</small>
                <Link href={`?anomalyId=${item.id}`}>{t.seeExplain} →</Link>
              </div>
            </article>
          ))}
          {!findings.length ? <article className="diag-conn-item"><p>{m.noFinding}</p></article> : null}
        </section>

        <section className="diag-conn-col">
          <header className="diag-conn-col-head" data-tone="coral">
            <h2><AlertTriangle size={16} aria-hidden />{t.anomaliesTitle}<span className="diag-conn-count">{anomalies.length}</span></h2>
            <p>{t.anomaliesLead}</p>
          </header>
          {anomalies.map((item) => (
            <article key={item.id} className="diag-conn-item">
              <h3>{locale === "ar" ? item.titleAr : item.titleFr}</h3>
              <span className="diag-conn-badge" data-tone={item.severity === "CRITICAL" || item.severity === "HIGH" ? "coral" : "amber"}>
                {item.severity === "CRITICAL" || item.severity === "HIGH" ? t.confidenceHigh : t.confidenceMid}
              </span>
              <p><strong>{locale === "fr" ? "Pourquoi : " : "لماذا: "}</strong>{String(item.explanation.summary ?? item.explanation.reason ?? "")}</p>
              <div className="diag-conn-item-foot">
                <small>2 {t.proofs}</small>
                <Link href={`?anomalyId=${item.id}`}>{t.seeExplain} →</Link>
              </div>
            </article>
          ))}
        </section>

        <section className="diag-conn-col">
          <header className="diag-conn-col-head" data-tone="amber">
            <h2><Lightbulb size={16} aria-hidden />{t.opps}<span className="diag-conn-count">{opportunities.length}</span></h2>
            <p>{t.oppsLead}</p>
          </header>
          {opportunities.map((item) => (
            <article key={item.id} className="diag-conn-item">
              <h3>{locale === "ar" ? (item.serviceNameAr ?? `${m.priority} ${item.priority}`) : (item.serviceNameFr ?? `${m.priority} ${item.priority}`)}</h3>
              <span className="diag-conn-badge" data-tone="mint">{m.statuses[item.status]}</span>
              <p>{m.whyOpportunity}</p>
              <div className="diag-conn-item-foot">
                <small>{labelSolutionLevel(locale, item.solutionLevel)}</small>
                <Link href={solutionsHref}>{t.seeExplain} →</Link>
              </div>
            </article>
          ))}
        </section>

        <section className="diag-conn-col">
          <header className="diag-conn-col-head" data-tone="violet">
            <h2><Target size={16} aria-hidden />{t.planTitle}</h2>
            <p>{t.planLead}</p>
          </header>
          <ol className="diag-conn-plan">
            {plan.map((item, index) => (
              <li key={item.id}>
                <span>{index + 1}</span>
                <div>
                  <strong>{locale === "ar" ? item.titleAr : item.titleFr}</strong>
                  <small>{m.priority}: {item.priority} · {labelSolutionLevel(locale, item.solutionLevel)}</small>
                </div>
                <span className="diag-conn-badge" data-tone={index < 2 ? "coral" : "amber"}>{index < 2 ? t.priorityHigh : t.priorityMid}</span>
              </li>
            ))}
          </ol>
          <Link href={solutionsHref} className="diag-conn-btn" style={{ justifyContent: "center" }}>{t.act}<ArrowRight className="rtl-mirror" size={16} aria-hidden /></Link>
        </section>
      </div>

      <p className="diag-conn-footer-help">
        <span>{t.help}</span>
        <Link href={listHref}>{t.back}</Link>
      </p>
    </div>
  );
}
