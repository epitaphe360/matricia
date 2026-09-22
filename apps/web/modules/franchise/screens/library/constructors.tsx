import Link from "next/link";
import {
  Beaker,
  Check,
  CheckCircle2,
  Eye,
  FileText,
  GitBranch,
  ListOrdered,
  Monitor,
  Plus,
  RotateCcw,
  Send,
  Smartphone,
  Trash2,
} from "lucide-react";
import { QuestionnaireBuilder } from "@/modules/admin/screens/catalogue/questionnaire-builder";
import { QuestionBuilder } from "@/modules/admin/screens/catalogue/question-builder";
import { RuleBuilder } from "@/modules/admin/screens/catalogue/rule-builder";
import { getBuilderMessages } from "@/modules/admin/screens/catalogue/messages";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import type { FranchiseCatalogRow, FranchiseLibraryWorkspace, FranchiseQuestionRow } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { MandateBanner, StatusChip } from "./library-boards";
import { FranchiseCatalogSubmitForm } from "./catalog-commands";
import { FranchiseServiceCommandForms, FranchiseServiceDraftForm } from "./service-builder";
import { FranchiseQuestionnaireSandbox } from "./sandbox-form";

function answerTypeLabel(type: string | null, locale: Locale) {
  const fr: Record<string, string> = {
    YES_NO: "Oui / Non",
    SINGLE_CHOICE: "Choix unique",
    INTEGER: "Nombre",
    SHORT_TEXT: "Réponse courte",
    LONG_TEXT: "Texte long",
    DATE: "Date",
    MONEY: "Montant",
  };
  const ar: Record<string, string> = {
    YES_NO: "نعم / لا",
    SINGLE_CHOICE: "اختيار واحد",
    INTEGER: "عدد",
    SHORT_TEXT: "إجابة قصيرة",
    LONG_TEXT: "نص طويل",
    DATE: "تاريخ",
    MONEY: "مبلغ",
  };
  return (locale === "ar" ? ar : fr)[type ?? ""] ?? type ?? "—";
}

function Stepper({
  steps,
  current,
}: {
  steps: readonly string[];
  current: number;
}) {
  return (
    <ol className="franchise-stepper" aria-label="Étapes">
      {steps.map((label, index) => (
        <li key={label} data-active={index === current ? "true" : undefined} data-done={index < current ? "true" : undefined}>
          <em>{index < current ? <Check className="size-3.5" aria-hidden /> : index + 1}</em>
          <span>{label}</span>
        </li>
      ))}
    </ol>
  );
}

function BuilderFooter({
  locale,
  query,
  cancelHref,
  simulateHref,
  submitHref,
  draftSaved,
}: {
  locale: Locale;
  query: string;
  cancelHref: string;
  simulateHref: string;
  submitHref: string;
  draftSaved: boolean;
}) {
  const c = libraryCopy(locale);
  return (
    <footer className="franchise-builder-footer">
      <Link href={cancelHref} className="franchise-tool">{c.cancel}</Link>
      <p className="franchise-autosave" role="status">
        {draftSaved ? <CheckCircle2 className="size-4" aria-hidden /> : null}
        <span>
          <strong>{c.autoSaved}</strong>
          <small>{c.lastSavedJustNow}</small>
        </span>
      </p>
      <div className="franchise-builder-actions">
        <Link href={cancelHref} className="franchise-tool">{c.saveDraft}</Link>
        <Link href={simulateHref} className="franchise-tool franchise-tool-mint"><Beaker className="size-4" aria-hidden /> {c.simulate}</Link>
        <Link href={submitHref} className="franchise-tool franchise-tool-primary"><Send className="size-4" aria-hidden /> {c.submitMatricia}</Link>
      </div>
    </footer>
  );
}

export function FranchiseServiceConstructor({
  locale,
  query,
  workspace,
  service,
  createMode,
  commandIdentity,
  organizationId,
}: {
  locale: Locale;
  query: string;
  workspace: FranchiseLibraryWorkspace;
  service: FranchiseCatalogRow | null;
  createMode: boolean;
  commandIdentity: { idempotencyKey: string; correlationId: string };
  organizationId: string | null;
}) {
  const c = libraryCopy(locale);
  const steps = c.serviceSteps;
  const title = service?.title ?? c.createService;
  const description = service?.description ?? c.servicePreviewFallback;
  const deliverables = c.serviceDeliverables;
  return (
    <main className="client-page">
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <header className="franchise-builder-head">
        <div>
          <h2>{c.serviceConstructorTitle}</h2>
          <p>{c.serviceConstructorLead}</p>
        </div>
        {service ? <StatusChip status={service.status} locale={locale} /> : <em className="client-status-chip" data-tone="violet">{c.validationPending}</em>}
      </header>
      <Stepper steps={steps} current={0} />
      <section className="franchise-constructor-grid">
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{c.generalInfo}</h2>
            <span className="franchise-lang-toggle" aria-hidden><em data-active="true">FR</em><em>AR</em></span>
          </header>
          {createMode || !service ? (
            <FranchiseServiceDraftForm locale={locale} workspace={workspace} commandIdentity={commandIdentity} organizationId={organizationId} />
          ) : service.command ? (
            <FranchiseServiceCommandForms locale={locale} workspace={workspace} service={service} commandIdentity={commandIdentity} organizationId={organizationId} />
          ) : (
            <dl className="franchise-props">
              <div><small>{c.labelFr}</small><span>{service.nameFr ?? service.title}</span></div>
              <div><small>{c.labelAr}</small><span dir="rtl" lang="ar">{service.nameAr ?? "—"}</span></div>
              <div><small>{c.linked}</small><span>{service.category ?? "—"} / {service.subcategory ?? "—"}</span></div>
              <div><small>{c.version}</small><span>{service.versionLabel ?? "—"}</span></div>
            </dl>
          )}
          <section className="franchise-deliverables">
            <h3>{c.expectedDeliverables}</h3>
            <ul>
              {deliverables.map((item) => (
                <li key={item}>
                  <span className="franchise-drag-handle" aria-hidden />
                  <strong>{item}</strong>
                  <button type="button" className="franchise-icon-btn" aria-label={locale === "ar" ? "حذف" : "Retirer"}>
                    <Trash2 className="size-3.5" aria-hidden />
                  </button>
                </li>
              ))}
            </ul>
            <button type="button" className="franchise-tool franchise-tool-ghost"><Plus className="size-4" aria-hidden /> {c.addDeliverable}</button>
            <p className="client-access-note">{c.addDeliverableHint}</p>
          </section>
        </article>
        <aside className="client-card franchise-client-preview">
          <header className="client-priority-head">
            <h2>{c.clientPreview}</h2>
            <span className="franchise-lang-toggle" aria-hidden><em data-active="true">FR</em><em>AR</em></span>
          </header>
          <article className="franchise-preview-card">
            <span className="franchise-kpi-icon" data-tone="violet"><FileText className="size-4" aria-hidden /></span>
            <div>
              <strong>{title}</strong>
              <em className="client-status-chip" data-tone="mint">{c.serviceKind}</em>
            </div>
            <p>{description}</p>
            <h3>{c.includedDeliverables}</h3>
            <ul className="franchise-check-list">
              {deliverables.map((item) => (
                <li key={item}><CheckCircle2 className="size-4" aria-hidden />{item}</li>
              ))}
            </ul>
          </article>
          <p className="franchise-mandate-banner" role="note">{c.previewIndicative}</p>
        </aside>
      </section>
      <BuilderFooter
        locale={locale}
        query={query}
        cancelHref={`/${locale}/franchise/services${query}`}
        simulateHref={service ? `/${locale}/franchise/services/${service.id}/simulation${query}` : `/${locale}/franchise/services${query}`}
        submitHref={service ? `/${locale}/franchise/services/${service.id}/validation${query}` : `/${locale}/franchise/validations${query}`}
        draftSaved
      />
    </main>
  );
}

export function FranchiseQuestionnaireConstructor({
  locale,
  query,
  workspace,
  selectedId,
  createMode,
  commandIdentity,
  organizationId = null,
}: {
  locale: Locale;
  query: string;
  workspace: FranchiseLibraryWorkspace;
  selectedId: string | null;
  createMode: boolean;
  commandIdentity: { idempotencyKey: string; correlationId: string };
  organizationId?: string | null;
}) {
  const c = libraryCopy(locale);
  const selected = workspace.questionnaires.find((item) => item.id === selectedId) ?? workspace.questionnaires[0] ?? null;
  const bank = workspace.questions;
  const inQuestionnaire = bank.filter((item) => selected && (item.questionnaireId === selected.id || item.questionnaireId === null));
  const selectedQuestion: FranchiseQuestionRow | null = inQuestionnaire[0] ?? bank[0] ?? null;
  const firstService = workspace.services[0] ?? null;
  const messages = getBuilderMessages(locale);
  return (
    <main className="client-page">
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <header className="franchise-builder-head">
        <div>
          <h2>{c.questionnaireConstructorTitle}</h2>
          <p>{c.questionnaireConstructorLead}</p>
        </div>
        <p className="franchise-autosave" role="status"><CheckCircle2 className="size-4" aria-hidden /><span><strong>{c.autoSaved}</strong></span></p>
      </header>
      <Stepper steps={c.questionnaireSteps} current={1} />
      <section className="franchise-constructor-triple">
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{c.questionBank} <small dir="ltr">({bank.length})</small></h2>
          </header>
          <form className="franchise-filters" action={`/${locale}/franchise/questionnaires`} method="get">
            <label className="franchise-search"><span className="sr-only">{c.search}</span><input name="q" placeholder={c.searchQuestion} /></label>
            <select defaultValue="all" aria-label={c.queueAllTypes}><option value="all">{c.queueAllTypes}</option></select>
            <select defaultValue="all" aria-label={c.categoriesOfLibrary}><option value="all">{c.categoriesOfLibrary}</option></select>
          </form>
          {bank.length === 0 ? <p>{c.emptyQuestions}</p> : (
            <ul className="franchise-bank-list">
              {bank.map((item) => (
                <li key={item.id}>
                  <span className="franchise-kpi-icon" data-tone="violet"><FileText className="size-4" aria-hidden /></span>
                  <span>
                    <strong>{item.label}</strong>
                    <small>{answerTypeLabel(item.answerType, locale)}</small>
                  </span>
                  <em className="franchise-kind-chip">FR / AR</em>
                  <span className="franchise-add-chip" aria-hidden><Plus className="size-3.5" /></span>
                </li>
              ))}
            </ul>
          )}
          {firstService ? (
            <details className="franchise-builder">
              <summary className="franchise-tool franchise-tool-primary"><Plus className="size-4" aria-hidden /> {c.addQuestion}</summary>
              <QuestionBuilder
                locale={locale}
                library={{ id: workspace.mandate.libraryId, code: workspace.mandate.libraryCode }}
                service={{ id: firstService.id, code: firstService.code }}
                messages={messages}
                commandIdentity={commandIdentity}
              />
            </details>
          ) : null}
        </article>
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{selected ? selected.title : c.yourQuestionnaire} <small dir="ltr">({inQuestionnaire.length})</small></h2>
            <Link href={selected ? `${selected.href}${query}` : `/${locale}/franchise/questionnaires/nouveau${query}`} className="franchise-tool"><ListOrdered className="size-4" aria-hidden /> {c.reorder}</Link>
          </header>
          {selected ? <StatusChip status={selected.status} locale={locale} /> : null}
          {inQuestionnaire.length === 0 ? <p>{c.emptyQuestions}</p> : (
            <ol className="franchise-question-cards">
              {inQuestionnaire.map((item, index) => (
                <li key={item.id} data-selected={selectedQuestion?.id === item.id ? "true" : undefined}>
                  <span className="client-num">{index + 1}</span>
                  <span>
                    <em className="franchise-kind-chip">{answerTypeLabel(item.answerType, locale)}</em>
                    <strong>{item.label}</strong>
                    <small>FR / AR</small>
                  </span>
                  <em className="client-status-chip" data-tone={item.required ? "peach" : "sky"}>{item.required ? c.requiredAnswer : c.optionalAnswer}</em>
                  {index === 3 ? <p className="franchise-branch-hint" data-tone="mint">{c.branchIfYes}</p> : null}
                  {index === 4 ? <p className="franchise-branch-hint" data-tone="peach">{c.branchShownIf}</p> : null}
                </li>
              ))}
            </ol>
          )}
        </article>
        <aside className="client-card">
          <header><h2>{c.questionProperties}</h2></header>
          {createMode || !selected ? (
            <QuestionnaireBuilder
              locale={locale}
              library={{ id: workspace.mandate.libraryId, code: workspace.mandate.libraryCode, currentReleaseId: workspace.mandate.currentReleaseId }}
              messages={messages}
              commandIdentity={commandIdentity}
            />
          ) : selectedQuestion ? (
            <form className="franchise-props-form">
              <label className="franchise-field">{c.labelFr}<input readOnly value={selectedQuestion.labelFr ?? selectedQuestion.label} /></label>
              <label className="franchise-field">{c.labelAr}<input readOnly dir="rtl" lang="ar" value={selectedQuestion.labelAr ?? ""} /></label>
              <label className="franchise-field">{c.helpFr}<textarea readOnly rows={2} value={selectedQuestion.helpFr ?? selectedQuestion.help ?? ""} /></label>
              <label className="franchise-field">{c.questionType}<input readOnly value={answerTypeLabel(selectedQuestion.answerType, locale)} /></label>
              <p className="client-access-note">{c.requiredAnswer}: {selectedQuestion.required ? (locale === "ar" ? "نعم" : "Oui") : (locale === "ar" ? "لا" : "Non")}</p>
              <p className="client-access-note">{c.conditionalVisibility}: {c.alwaysShown}</p>
            </form>
          ) : (
            <p>{c.emptyQuestions}</p>
          )}
          {selected && !createMode ? (
            <FranchiseCatalogSubmitForm locale={locale} workspace={workspace} item={selected} commandIdentity={commandIdentity} organizationId={organizationId} />
          ) : null}
        </aside>
      </section>
      <footer className="franchise-builder-footer">
        <Link href={`/${locale}/franchise/questionnaires${query}`} className="franchise-tool">{c.cancel}</Link>
        <p className="franchise-autosave" role="status"><CheckCircle2 className="size-4" aria-hidden /><span><strong>{c.autoSaved}</strong></span></p>
        <div className="franchise-builder-actions">
          <Link href={selected ? `/${locale}/franchise/questionnaires/${selected.id}/simulation${query}` : `/${locale}/franchise/questionnaires${query}`} className="franchise-tool"><GitBranch className="size-4" aria-hidden /> {c.testBranches}</Link>
          <Link href={selected ? `/${locale}/franchise/questionnaires/${selected.id}/apercu${query}` : `/${locale}/franchise/questionnaires${query}`} className="franchise-tool"><Eye className="size-4" aria-hidden /> {c.previewClient}</Link>
          <Link href={`/${locale}/franchise/validations${query}`} className="franchise-tool franchise-tool-primary"><Send className="size-4" aria-hidden /> {c.submitMatricia}</Link>
        </div>
      </footer>
    </main>
  );
}

export function FranchiseClientPreviewBranches({
  locale,
  query,
  workspace,
  questionnaireId,
  organizationId = null,
}: {
  locale: Locale;
  query: string;
  workspace: FranchiseLibraryWorkspace;
  questionnaireId: string | null;
  organizationId?: string | null;
}) {
  const c = libraryCopy(locale);
  const selected = workspace.questionnaires.find((item) => item.id === questionnaireId) ?? workspace.questionnaires[0] ?? null;
  const questions = workspace.questions.filter((item) => !selected || item.questionnaireId === selected.id || item.questionnaireId === null);
  const current = questions[2] ?? questions[0] ?? null;
  const total = Math.max(questions.length, 1);
  const position = current ? Math.min(3, total) : 1;
  return (
    <main className="client-page">
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <p className="franchise-sim-banner" role="note">{c.simulationNoEffect}</p>
      <header className="franchise-builder-head">
        <div>
          <h2>{c.clientPreviewBranchesTitle}</h2>
          <p>{c.clientPreviewBranchesLead}</p>
        </div>
      </header>
      <div className="franchise-toolbar">
        <label className="franchise-field">
          <span className="sr-only">{c.questionnairesTitle}</span>
          <select defaultValue={selected?.id ?? ""} aria-label={c.questionnairesTitle}>
            {(workspace.questionnaires.length ? workspace.questionnaires : [{ id: "", title: c.emptyQuestionnaires }]).map((item) => (
              <option key={item.id || "empty"} value={item.id}>{item.title}</option>
            ))}
          </select>
        </label>
        <label className="franchise-field">
          <span className="sr-only">{c.testScenario}</span>
          <select defaultValue="default" aria-label={c.testScenario}>
            <option value="default">{c.defaultScenario}</option>
          </select>
        </label>
        <Link href={selected ? `/${locale}/franchise/questionnaires/${selected.id}/versions${query}` : `/${locale}/franchise/questionnaires${query}`} className="franchise-tool">{c.compareVersions}</Link>
        <Link href={selected ? `/${locale}/franchise/questionnaires/${selected.id}/simulation${query}` : `/${locale}/franchise/questionnaires${query}`} className="franchise-tool"><RotateCcw className="size-4" aria-hidden /> {c.resetScenario}</Link>
      </div>
      <section className="franchise-preview-branches">
        <article className="client-card">
          <header className="client-priority-head">
            <h2>{c.clientPreview}</h2>
            <nav className="franchise-device-toggle" aria-label={c.deviceToggle}>
              <button type="button" data-active="true"><Monitor className="size-4" aria-hidden /> {c.deviceDesktop}</button>
              <button type="button"><Smartphone className="size-4" aria-hidden /> {c.deviceMobile}</button>
            </nav>
          </header>
          <div className="franchise-client-frame">
            <span className="franchise-progress-bar" aria-hidden><span style={{ width: `${Math.round((position / total) * 100)}%` }} /></span>
            <p className="client-access-note">{c.questionOf.replace("{n}", String(position)).replace("{total}", String(total))}</p>
            {current ? (
              <div className="franchise-preview-question">
                <h3>{current.label}</h3>
                <p>{current.help ?? c.selectBestAnswer}</p>
                <ul className="franchise-choice-list">
                  {c.previewChoices.map((choice, index) => (
                    <li key={choice} data-selected={index === 0 ? "true" : undefined}>
                      <span /><strong>{choice}</strong>
                    </li>
                  ))}
                </ul>
                <div className="franchise-preview-nav">
                  <button type="button" className="franchise-tool" disabled>{c.previous}</button>
                  <button type="button" className="franchise-tool franchise-tool-primary">{c.nextStep}</button>
                </div>
              </div>
            ) : <p>{c.emptyQuestions}</p>}
          </div>
        </article>
        <aside className="client-card">
          <header><h2>{c.branchAnalysis}</h2></header>
          <section>
            <h3>{c.currentPath}</h3>
            <ul className="franchise-branch-path">
              <li>
                <strong>Q{position}</strong>
                <span>{current?.label ?? "—"}</span>
                <em className="client-status-chip" data-tone="mint">{c.applied}</em>
              </li>
              <li>
                <strong>Q{position + 1}</strong>
                <span>{questions[position]?.label ?? c.nextQuestionHint}</span>
                <em className="client-status-chip" data-tone="sky">{c.willShow}</em>
                <small>{c.displayCondition}</small>
              </li>
            </ul>
          </section>
          <section>
            <h3>{c.nonApplicableBranches}</h3>
            <ul className="franchise-branch-path">
              {c.hiddenBranchHints.map((hint) => (
                <li key={hint}><strong>—</strong><span>{hint}</span><em className="client-status-chip" data-tone="peach">{c.notApplicable}</em></li>
              ))}
            </ul>
          </section>
          <section className="franchise-test-result">
            <p>{c.testResultSummary.replace("{n}", String(Math.max(total - position, 0)))}</p>
            <p>{c.estimatedEnd.replace("{n}", String(total)).replace("{total}", String(total))}</p>
            <p>{c.estimatedTime}</p>
          </section>
          <section id="simulation">
            <h3>{c.sandbox}</h3>
            <FranchiseQuestionnaireSandbox locale={locale} workspace={workspace} organizationId={organizationId} selectedQuestionnaireId={selected?.id ?? null} />
          </section>
        </aside>
      </section>
    </main>
  );
}

export function FranchiseRuleConstructor({
  locale,
  query,
  workspace,
  selectedId,
  createMode,
  commandIdentity,
  organizationId = null,
}: {
  locale: Locale;
  query: string;
  workspace: FranchiseLibraryWorkspace;
  selectedId: string | null;
  createMode: boolean;
  commandIdentity: { idempotencyKey: string; correlationId: string };
  organizationId?: string | null;
}) {
  const c = libraryCopy(locale);
  const selected = workspace.rules.find((item) => item.id === selectedId) ?? workspace.rules[0] ?? null;
  const messages = getBuilderMessages(locale);
  return (
    <main className="client-page">
      <MandateBanner locale={locale} name={workspace.mandate.libraryName} />
      <header className="franchise-builder-head">
        <div>
          <h2>{c.ruleConstructorTitle}</h2>
          <p>{c.ruleConstructorLead}</p>
        </div>
        {selected ? <StatusChip status={selected.status} locale={locale} /> : <em className="client-status-chip" data-tone="violet">{c.validationPending}</em>}
      </header>
      <section className="franchise-rule-layout">
        <article className="client-card">
          <dl className="franchise-props">
            <div><small>{c.ruleName}</small><span>{selected?.title ?? c.newRule}</span></div>
            <div><small>{c.version}</small><span>{selected?.versionLabel ?? "v1.0"}</span></div>
            <div><small>{c.languages}</small><span>FR · AR</span></div>
            <div><small>{c.provenance}</small><span>{workspace.questionnaires[0]?.title ?? workspace.mandate.libraryName}</span></div>
          </dl>
          <section className="franchise-rule-flow">
            <article className="franchise-rule-node" data-tone="violet">
              <header><strong>{c.ruleIf}</strong><small>{c.ruleAllConditions}</small></header>
              <ul>
                <li>{c.ruleConditionSample1}</li>
                <li>{c.ruleConditionSample2}</li>
              </ul>
              <p className="client-soft-link">+ {c.addCondition}</p>
            </article>
            <article className="franchise-rule-node" data-tone="mint">
              <header><strong>{c.ruleThen}</strong><em className="client-status-chip" data-tone="peach">{c.priorityHigh}</em></header>
              <p>{c.ruleThenSample}</p>
            </article>
            <article className="franchise-rule-node" data-tone="peach">
              <header><strong>{c.ruleElse}</strong><em className="client-status-chip" data-tone="mint">{c.priorityNormal}</em></header>
              <p>{c.ruleElseSample}</p>
            </article>
          </section>
          <details className="franchise-builder" open={createMode || !selected}>
            <summary>{c.createRule}</summary>
            <RuleBuilder
              locale={locale}
              library={{ id: workspace.mandate.libraryId, code: workspace.mandate.libraryCode }}
              messages={messages}
              commandIdentity={commandIdentity}
            />
          </details>
          {selected ? (
            <FranchiseCatalogSubmitForm locale={locale} workspace={workspace} item={selected} commandIdentity={commandIdentity} organizationId={organizationId} />
          ) : null}
        </article>
        <aside className="client-card">
          <header><h2>{c.ruleSummary}</h2></header>
          <ul className="franchise-dot-list">
            <li><span className="franchise-dot" data-tone="violet" /><strong>{selected?.title ?? c.newRule}</strong></li>
            <li><span className="franchise-dot" data-tone="mint" /><strong>{c.ruleThen}</strong><small>{c.ruleThenSample}</small></li>
            <li><span className="franchise-dot" data-tone="peach" /><strong>{c.ruleElse}</strong><small>{c.ruleElseSample}</small></li>
          </ul>
          <p className="franchise-warning" role="note">{c.ruleMustSubmit}</p>
        </aside>
      </section>
      <BuilderFooter
        locale={locale}
        query={query}
        cancelHref={`/${locale}/franchise/regles${query}`}
        simulateHref={`/${locale}/franchise/regles${query}#simulation`}
        submitHref={`/${locale}/franchise/validations${query}`}
        draftSaved
      />
    </main>
  );
}
