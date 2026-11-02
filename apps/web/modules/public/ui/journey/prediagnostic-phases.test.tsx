import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { diagnosticQuestionIds } from "@/modules/public/data/journey/diagnostic-contract";
import { DetailView, HonestStatesView, RecapView, RecoveryStatesView } from "./prediagnostic-phases";

describe("états publics du prédiagnostic", () => {
  it("n’affiche qu’un constat réel quand aucune priorité n’est détectée", () => {
    const html = renderToStaticMarkup(<HonestStatesView locale="fr" onEdit={() => undefined} onAssist={() => undefined} />);
    expect(html).toContain("Aucune priorité majeure détectée");
    expect(html.match(/<h2/g)?.length).toBe(1);
    expect(html).not.toContain("92%");
    expect(html).not.toContain("44 / 48");
    expect(html).not.toContain("83%");
  });

  it("n’affiche pas trois pannes fictives quand le stockage local échoue", () => {
    const html = renderToStaticMarkup(<RecoveryStatesView locale="fr" onRetry={() => undefined} onContinue={() => undefined} onReconnect={() => undefined} />);
    expect(html).toContain("n’a pas pu être conservé");
    expect(html.match(/<h2/g)?.length).toBe(1);
    expect(html).not.toContain("Mise à jour disponible");
    expect(html).not.toContain("Session expirée");
  });

  it("propose uniquement les secteurs que le contrat d’enregistrement accepte", () => {
    const sectors = getPublicJourneyCopy("fr").diagnostic.questions[0]?.[2] ?? [];
    const arabic = getPublicJourneyCopy("ar").diagnostic.questions[0]?.[2] ?? [];
    expect(sectors).toEqual(["Industrie & production", "Commerce & distribution", "Services & conseil", "BTP, immobilier & aménagement", "Autre activité"]);
    expect(arabic).toHaveLength(sectors.length);
    expect(String(sectors)).not.toContain("Santé");
  });
});

describe.each(["fr", "ar"] as const)("diagnostic answer trace in %s", (locale) => {
  const answers = { sector: "construction", team_size: "small", goals: ["control_costs"], priority_tracking: "no", sales_tracking: "manual", backup_restore: "not_applicable", decision_trace: "partial", next_action: "Préparer mon chantier sans perdre les réponses" };

  it("associates the eight summary labels with their actual saved data", () => {
    const html = renderToStaticMarkup(<RecapView locale={locale} answers={answers} onEdit={() => undefined} onBack={() => undefined} onAnalyze={() => undefined} />);
    const copy = getPublicJourneyCopy(locale).diagnostic;
    expect(copy.steps[4]).toBe(locale === "fr" ? "Suivi commercial" : "المتابعة التجارية");
    expect(copy.steps[5]).toBe(locale === "fr" ? "Restauration des sauvegardes" : "استعادة النسخ الاحتياطية");
    expect(html).toMatch(locale === "fr" ? /Restauration des sauvegardes<[^]*?Non concerné/ : /استعادة النسخ الاحتياطية<[^]*?غير معني/);
    expect(html).toContain(answers.next_action);
    const values = locale === "fr"
      ? ["BTP, immobilier & aménagement", "1 à 9 personnes", "Maîtriser mes coûts", "Non", "Tableaux manuels", "Non concerné", "Seulement pour certains sujets", answers.next_action]
      : ["بناء وعقار وتهيئة", "1 إلى 9 أشخاص", "ضبط التكاليف", "لا", "جداول يدوية", "غير معني", "لبعض المواضيع فقط", answers.next_action];
    for (const [index, id] of diagnosticQuestionIds.entries()) {
      const row = html.split(`data-question="${id}"`)[1]!.split("</div>")[0]!;
      expect(row).toContain(copy.questionLabels[id]);
      expect(row).toContain(renderToStaticMarkup(<>{values[index]}</>));
    }
  });

  it("quotes the actual triggering answer separately from the recommendation and defines three distinct actions", () => {
    const html = renderToStaticMarkup(<DetailView locale={locale} priority="organization" answers={answers} onBack={() => undefined} />);
    expect(html).toContain(locale === "fr" ? "« Non »" : "« لا »");
    expect(html).toContain(getPublicJourneyCopy(locale).diagnostic.questions[3]![0]);
    expect(html).toContain(locale === "fr" ? "Responsable proposé" : "المسؤول المقترح");
    expect(html).toContain(locale === "fr" ? "Livrable" : "المخرج");
    expect(html).toContain(locale === "fr" ? "Terminé lorsque" : "يكتمل عندما");
    const recommendation = getPublicJourneyCopy(locale).diagnostic.priorities.organization[3];
    expect(html.split(recommendation).length - 1).toBeLessThan(2);
    expect(html).toContain('data-question="priority_tracking"');
    expect(html).not.toContain('data-question="sales_tracking"');
    expect(html).toContain(`href="/${locale}/a-propos">${locale === "fr" ? "En savoir plus sur Matricia" : "تعرّفوا أكثر على ماتريسيا"}`);
  });

  it("does not substitute an unrecognized backup answer with not applicable", () => {
    const html = renderToStaticMarkup(<RecapView locale={locale} answers={{ ...answers, backup_restore: "invalid-saved-value" }} onEdit={() => undefined} onBack={() => undefined} onAnalyze={() => undefined} />);
    const row = html.split('data-question="backup_restore"')[1]!.split("</div>")[0]!;
    expect(row).toContain(getPublicJourneyCopy(locale).diagnostic.answerUnavailable);
    expect(row).not.toContain(locale === "fr" ? "Non concerné" : "غير معني");
  });

  it.each(["sales", "security", "verify"] as const)("anchors the %s plan to matching answers and distinct deliverables", (priority) => {
    const source = { ...answers, sales_tracking: "manual", backup_restore: "no", decision_trace: "unknown" };
    const html = renderToStaticMarkup(<DetailView locale={locale} priority={priority} answers={source} onBack={() => undefined} />);
    const plan = getPublicJourneyCopy(locale).diagnostic.actionPlans[priority];
    expect(new Set(plan.map((step) => step.action)).size).toBe(3);
    expect(new Set(plan.map((step) => step.deliverable)).size).toBe(3);
    for (const step of plan) {
      expect(html).toContain(renderToStaticMarkup(<>{step.action}</>));
      expect(html).toContain(renderToStaticMarkup(<>{step.deliverable}</>));
      expect(html).toContain(renderToStaticMarkup(<>{step.owner}</>));
      expect(html).toContain(renderToStaticMarkup(<>{step.done}</>));
    }
  });
});
