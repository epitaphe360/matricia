"use client";

import Link from "next/link";
import { useActionState, useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, ArrowLeft, ArrowRight, Building2, CheckCircle2, CircleHelp, Factory, HeartPulse, Landmark, MoreHorizontal, ShoppingCart, Sparkles, Trash2 } from "lucide-react";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/modules/public/data/journey/copy";
import { diagnosticQuestionIds as questionIds, parseStoredDiagnostic, type DiagnosticAnswer as Answer, type DiagnosticQuestionId as QuestionId, type StoredDiagnostic as Stored } from "./diagnostic-storage";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";

const storageKey = "matricia.public-diagnostic.v2";
const legacyKeys = ["matricia.public-diagnostic", "matricia.public-diagnostic.fr", "matricia.public-diagnostic.ar"];
const optionIds: Record<Exclude<QuestionId, "next_action">, readonly string[]> = {
  sector: ["industry_logistics", "commerce", "professional_services", "construction", "health_social", "other"],
  team_size: ["solo", "small", "medium", "large"],
  goals: ["save_time", "control_costs", "grow_sales", "secure_activity", "global_review"],
  priority_tracking: ["regular", "partial", "no", "unknown"],
  sales_tracking: ["shared", "manual", "ad_hoc", "unknown"],
  backup_restore: ["recent", "old", "no", "unknown", "not_applicable"],
  decision_trace: ["systematic", "partial", "no", "unknown"],
};
const legacyQuestionIds = ["goals", "sector", "team_size", "priority_tracking", "sales_tracking", "backup_restore", "decision_trace", "next_action"] as const;
const initial = (): Stored => ({ version: 2, expiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000, step: 0, answers: {} });
function convertLegacy(raw: string, locale: Locale): Stored | null {
  try {
    const value = JSON.parse(raw) as { expiresAt?: number; step?: number; answers?: Record<string, Answer>; locale?: Locale };
    if (!value.expiresAt || value.expiresAt <= Date.now() || !value.answers) return null;
    const source = getPublicJourneyCopy(value.locale === "ar" ? "ar" : locale).diagnostic.questions;
    const answers: Partial<Record<QuestionId, Answer>> = {};
    for (const [rawIndex, rawAnswer] of Object.entries(value.answers)) {
      const index = Number(rawIndex), id = legacyQuestionIds[index];
      if (!id || !(typeof rawAnswer === "string" || Array.isArray(rawAnswer) && rawAnswer.every((entry) => typeof entry === "string"))) continue;
      if (id === "next_action") answers[id] = rawAnswer;
      else {
        const labels = source[questionIds.indexOf(id)]?.[2] ?? [];
        const ids = optionIds[id];
        const convert = (label: string) => ids[labels.indexOf(label)] ?? "";
        const converted = Array.isArray(rawAnswer) ? rawAnswer.map(convert).filter(Boolean) : convert(rawAnswer);
        if (Array.isArray(converted) ? converted.length : converted) answers[id] = converted;
      }
    }
    return { version: 2, expiresAt: value.expiresAt, step: Math.min(Math.max(value.step ?? 0, 0), questionIds.length), answers };
  } catch { return null; }
}

type SaveState = { status: "idle" } | { status: "success"; intakeId: string } | { status: "error"; reason: "VALIDATION" | "FORBIDDEN" | "UNAVAILABLE" };
type OrganizationOption = { id: string; name: string };

export function PrediagnosticFlow({ locale, organizations = [], authenticated = false, saveAction }: { locale: Locale; organizations?: OrganizationOption[]; authenticated?: boolean; saveAction?: (state: SaveState, data: FormData) => Promise<SaveState> }) {
  const copy = getPublicJourneyCopy(locale).diagnostic;
  const router = useRouter();
  const [state, setState] = useState<Stored>(initial);
  const [loaded, setLoaded] = useState(false);
  const [storageAvailable, setStorageAvailable] = useState(true);
  const clearStored = useCallback(() => { try { window.localStorage.removeItem(storageKey); for (const key of legacyKeys) { window.localStorage.removeItem(key); window.sessionStorage.removeItem(key); } } catch { setStorageAvailable(false); } }, []);
  useEffect(() => {
    const timer = window.setTimeout(() => {
      try {
        let restored = parseStoredDiagnostic(window.localStorage.getItem(storageKey));
        if (!restored) for (const key of legacyKeys) { const raw = window.localStorage.getItem(key) ?? window.sessionStorage.getItem(key); if (raw) { restored = convertLegacy(raw, locale); if (restored) break; } }
        if (restored) setState(restored);
      } catch { setStorageAvailable(false); }
      setLoaded(true);
    }, 0);
    return () => window.clearTimeout(timer);
  }, [locale]);
  useEffect(() => {
    if (!loaded || !storageAvailable) return;
    try { window.localStorage.setItem(storageKey, JSON.stringify(state)); }
    catch { window.setTimeout(() => setStorageAvailable(false), 0); }
  }, [state, loaded, storageAvailable]);
  if (!loaded) return <main id="contenu-principal" className="journey-shell" dir={locale === "ar" ? "rtl" : "ltr"} aria-busy="true"><div className="journey-card"><p className="journey-eyebrow">{copy.eyebrow}</p><h1>{copy.title}</h1><p className="journey-intro">{copy.intro}</p><p>{locale === "fr" ? "Chargement de votre bilan…" : "جارٍ تحميل تقييمكم…"}</p></div></main>;
  if (state.step >= questionIds.length) return <Result locale={locale} answers={state.answers} storageAvailable={storageAvailable} organizations={organizations} authenticated={authenticated} saveAction={saveAction} onSaved={clearStored} onEdit={() => setState((current) => ({ ...current, step: 0, expiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000 }))} onErase={() => {
    clearStored();
    setState(initial());
  }} />;
  const questionId = questionIds[state.step]!, question = copy.questions[state.step], answer = state.answers[questionId];
  const choices = questionId === "next_action" ? [] : optionIds[questionId].map((id, index) => ({ id, label: question[2][index] ?? id }));
  const canProceed = choices.length ? Boolean(Array.isArray(answer) ? answer.length : answer) : typeof answer === "string" && answer.trim().length >= 3;
  const setAnswer = (value: Answer) => setState((current) => ({ ...current, answers: Object.fromEntries([...Object.entries(current.answers).filter(([key]) => questionIds.indexOf(key as QuestionId) <= current.step), [questionId, value]]) }));
  return <main id="contenu-principal" className="journey-shell" dir={locale === "ar" ? "rtl" : "ltr"}>
    <div className="journey-diag">
      <aside className="journey-side">
        <p className="journey-eyebrow">{copy.sideEyebrow}</p>
        <h2 className="mt-3 text-2xl font-semibold text-[#1a2340]">{copy.title}</h2>
        <p className="journey-intro mt-3">{copy.sideHelp}</p>
        <ul className="journey-trust">{copy.benefits.map((item) => <li key={item}><CheckCircle2 size={16} aria-hidden="true" />{item}</li>)}</ul>
        <p className="journey-intro mt-6">{copy.intro}</p>
        <PublicPhoto className="mt-6 min-h-[160px]" scene="koutoubia" caption={copy.photoCaption} />
      </aside>
      <section className="journey-card">
        <p className="journey-eyebrow">{copy.steps[state.step]}</p>
        <p className="journey-progress" aria-live="polite">{copy.progress(state.step + 1, questionIds.length)}</p>
        <div className="journey-progressbar" aria-hidden="true"><span style={{ width: ((state.step + 1) / questionIds.length) * 100 + "%" }} /></div>
        {!storageAvailable ? <p role="status" className="journey-login-note">{locale === "fr" ? "La sauvegarde locale est indisponible. Vous pouvez continuer en gardant cette page ouverte." : "الحفظ المحلي غير متاح. يمكنكم المتابعة مع إبقاء الصفحة مفتوحة."}</p> : null}
        <h1 id="diagnostic-question">{question[0]}</h1>
        <p className="journey-intro">{question[1]}</p>
        {choices.length ? <Choices label={String(question[0])} choices={choices} value={answer} multi={questionId === "goals"} icons={questionId === "sector"} onChange={setAnswer} /> : <textarea aria-labelledby="diagnostic-question" className="journey-textarea" autoFocus value={typeof answer === "string" ? answer : ""} onChange={(event) => setAnswer(event.target.value.slice(0, 500))} rows={5} maxLength={500} />}
        <p className="mt-2"><Link className="journey-known" href={`/${locale}/contact`}>{copy.helpChoose}</Link></p>
        <div className="journey-actions">{state.step > 0 ? <button type="button" className="journey-secondary" onClick={() => setState((current) => ({ ...current, step: current.step - 1 }))}><ArrowLeft className="rtl-mirror" aria-hidden="true" size={18}/>{copy.back}</button> : <Link className="journey-secondary" href={`/${locale}`}>{copy.back}</Link>}<button type="button" className="journey-primary" disabled={!canProceed} onClick={() => {
          const next = { ...state, step: state.step + 1, expiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000 };
          setState(next);
          try { window.localStorage.setItem(storageKey, JSON.stringify(next)); } catch { /* keep on-page if storage is blocked */ }
          if (next.step >= questionIds.length) router.push(`/${locale}/diagnostic/resultat`);
        }}>{state.step === questionIds.length - 1 ? copy.result : copy.next}<ArrowRight className="rtl-mirror" aria-hidden="true" size={18}/></button></div>
        <p className="mt-4 text-center text-sm text-slate-500">{copy.autoSave}</p>
      </section>
      <aside className="journey-rail">
        <p className="journey-eyebrow">{copy.railTitle}</p>
        <ol>{copy.steps.map((label, index) => <li key={label} className={index === state.step ? "is-current" : undefined}><span>{index + 1}</span><strong>{label}{index === state.step ? <em className="mt-1 block text-xs font-medium not-italic text-[#6d3cc7]">{copy.currentStep}</em> : null}</strong></li>)}</ol>
        <p className="mt-6 font-semibold text-[#1a2340]">{copy.aboutTitle}</p>
        <ul className="mt-3 space-y-2 text-sm leading-6 text-slate-600">{copy.aboutItems.map((item) => <li key={item}>{item}</li>)}</ul>
        <p className="mt-6 font-semibold text-[#1a2340]">{copy.changeLanguage}</p>
        <p className="mt-2 text-sm leading-6 text-slate-600">{copy.languageHelp}</p>
        <p className="mt-3 flex gap-3 text-sm font-semibold"><Link href={`/${locale}/diagnostic`} hrefLang={locale} lang={locale} aria-current="true">{locale.toUpperCase()}</Link><span aria-hidden="true">|</span><Link href={`/${locale === "fr" ? "ar" : "fr"}/diagnostic`} hrefLang={locale === "fr" ? "ar" : "fr"} lang={locale === "fr" ? "ar" : "fr"}>{locale === "fr" ? "AR" : "FR"}</Link></p>
      </aside>
    </div>
  </main>;
}

function Choices({ label, choices, value, multi, icons = false, onChange }: { label: string; choices: readonly { id: string; label: string }[]; value: Answer | undefined; multi: boolean; icons?: boolean; onChange: (value: Answer) => void }) {
  const selected = Array.isArray(value) ? value : value ? [value] : [];
  const sectorIcons = [Factory, ShoppingCart, Landmark, Building2, HeartPulse, MoreHorizontal];
  return <div className="journey-choices" role={multi ? "group" : "radiogroup"} aria-label={label}>{choices.map((choice, index) => { const checked = selected.includes(choice.id); const Icon = icons ? sectorIcons[index] ?? MoreHorizontal : null; return <button key={choice.id} type="button" role={multi ? undefined : "radio"} aria-pressed={multi ? checked : undefined} aria-checked={multi ? undefined : checked} tabIndex={multi || checked || !selected.length && index === 0 ? 0 : -1} className={checked ? "is-selected" : ""} onKeyDown={(event) => {
    if (multi || !["ArrowDown", "ArrowUp", "ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();
    const direction = event.key === "Home" ? -index : event.key === "End" ? choices.length - 1 - index : ["ArrowDown", "ArrowRight"].includes(event.key) ? 1 : -1;
    const nextIndex = (index + direction + choices.length) % choices.length;
    onChange(choices[nextIndex]!.id);
    event.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>("[role=radio]")[nextIndex]?.focus();
  }} onClick={() => multi ? onChange(checked ? selected.filter((item) => item !== choice.id) : [...selected, choice.id]) : onChange(choice.id)}>{Icon ? <span className="inline-flex items-center gap-3"><Icon aria-hidden="true" size={18} /><span>{choice.label}</span></span> : <span>{choice.label}</span>}<CheckCircle2 aria-hidden="true" size={20}/></button>; })}</div>;
}

function Result({ locale, answers, storageAvailable, organizations, authenticated, saveAction, onSaved, onEdit, onErase }: { locale: Locale; answers: Stored["answers"]; storageAvailable: boolean; organizations: OrganizationOption[]; authenticated: boolean; saveAction?: (state: SaveState, data: FormData) => Promise<SaveState>; onSaved: () => void; onEdit: () => void; onErase: () => void }) {
  const copy = getPublicJourneyCopy(locale).diagnostic;
  const [saveState, submitSave, savePending] = useActionState(saveAction ?? (async () => ({ status: "error", reason: "UNAVAILABLE" } as SaveState)), { status: "idle" } as SaveState);
  useEffect(() => { if (saveState.status === "success") onSaved(); }, [saveState.status, onSaved]);
  const priorities = useMemo(() => {
    const items: (keyof typeof copy.priorities)[] = [], goals = Array.isArray(answers.goals) ? answers.goals : [];
    if (answers.priority_tracking === "no" || answers.priority_tracking === "partial") items.push("organization");
    if (answers.sales_tracking === "manual" || answers.sales_tracking === "ad_hoc" || goals.includes("grow_sales") && answers.sales_tracking !== "shared") items.push("sales");
    if (answers.backup_restore === "no" || goals.includes("secure_activity") && answers.backup_restore === "old") items.push("security");
    if ([answers.priority_tracking, answers.sales_tracking, answers.backup_restore, answers.decision_trace].includes("unknown")) items.push("verify");
    return [...new Set(items)].slice(0, 3);
  }, [answers, copy]);
  const questionnaireHref = `/${locale}/client/questionnaires`;
  const diagnosticHref = `/${locale}/client/diagnostics`;
  const next = `/${locale}/connexion?mode=inscription&role=client&next=${encodeURIComponent(diagnosticHref)}`;
  const completeAnswers = questionIds.every((id) => answers[id] !== undefined);
  const kinds = { organization: "opportunity", sales: "declared", security: "risk", verify: "verify" } as const;
  const orientationNote = locale === "fr"
    ? "Ce résultat prépare le diagnostic. Il n’est pas une santé globale calculée. Le questionnaire versionné déclenche la chaîne réponse, règle, anomalie, recommandation, opportunité."
    : "هذه النتيجة تهيئ التشخيص وليست صحة عامة محسوبة. يطلق الاستبيان ذو الإصدار سلسلة الإجابة والقاعدة والاختلال والتوصية والفرصة.";
  return <main id="contenu-principal" className="journey-shell" dir={locale === "ar" ? "rtl" : "ltr"}><section className="journey-card journey-result" style={{ width: "min(100%, 1100px)" }}><div className="grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(220px,.7fr)] lg:items-start"><div><p className="journey-eyebrow">{copy.resultEyebrow}</p><h1>{copy.resultTitle}</h1><p className="journey-intro">{copy.loginNote}</p><p className="journey-based">{copy.basedOn}</p></div><PublicPhoto scene="arch" caption={locale === "ar" ? "مؤسسات أقوى لمغرب يتقدم" : "Des entreprises plus fortes pour un Maroc qui avance"} /></div><div className="journey-scope"><div><strong>{copy.scope}</strong><span>{locale === "fr" ? "Ce sujet a été analysé à partir de vos réponses." : "تم تحليل هذا الموضوع انطلاقاً من إجاباتكم."}</span></div><div><strong>{copy.unknownItems}</strong><span>{locale === "fr" ? "Certaines informations manquent pour aller plus loin." : "تنقص بعض المعلومات للمضي أبعد."}</span></div><div><strong>{copy.limits}</strong><span>{locale === "fr" ? "Ce sujet n’est pas concerné par votre activité." : "هذا الموضوع لا يخص نشاطكم."}</span></div></div>
    <div className="mt-6 grid gap-4 lg:grid-cols-[minmax(0,1.6fr)_minmax(240px,.7fr)]">
    {priorities.length ? <ol className="journey-priorities">{priorities.map((key, index) => { const item = copy.priorities[key], kind = kinds[key], Icon = kind === "risk" ? AlertTriangle : kind === "verify" ? CircleHelp : Sparkles; return <li key={key} data-kind={kind}><span>0{index + 1}</span><small className="journey-kind"><Icon aria-hidden="true" size={15}/>{copy.kindLabels[kind]}</small><h2>{item[0]}</h2><p><strong>{copy.constat}.</strong> {item[1]}</p><p><strong>{copy.whyItMatters}.</strong> {item[2]}</p><p><strong>{copy.recommendedAction}.</strong> {item[3]}</p><details><summary className="journey-known cursor-pointer">{copy.viewDetail}</summary><p className="mt-2 text-sm text-slate-600">{item[3]}</p></details></li>; })}</ol> : <p role="status" className="journey-login-note">{locale === "fr" ? "Aucune priorité particulière n’est ressortie du périmètre évalué. Ce résultat n’est pas une attestation." : "لم تظهر أولوية خاصة ضمن النطاق المقيم. هذه النتيجة ليست شهادة."}</p>}
    <aside className="journey-rail"><p className="font-semibold text-[#1a2340]">{copy.planTitle}</p><ul className="mt-4 space-y-2 text-sm leading-6 text-slate-600">{copy.planItems.map((item) => <li key={item}>{item}</li>)}</ul></aside>
    </div>
    {!authenticated ? <><div className="journey-actions"><Link className="journey-primary" href={next}>{copy.save}<ArrowRight className="rtl-mirror" aria-hidden="true" size={18}/></Link><Link className="journey-secondary" href={`/${locale}/besoin?source=diagnostic&priority=${encodeURIComponent(priorities[0] ?? "")}`}>{copy.assist}<ArrowRight className="rtl-mirror" aria-hidden="true" size={18}/></Link></div><button type="button" className="journey-known" onClick={onEdit}>{copy.restart}</button></> : organizations.length && saveAction ? <div className="journey-login-note"><p>{orientationNote}</p><div className="journey-actions mt-4"><button type="button" className="journey-secondary" onClick={onEdit}>{copy.restart}</button><Link className="journey-primary" href={questionnaireHref}>{copy.continueQuestionnaire}<ArrowRight className="rtl-mirror" aria-hidden="true" size={18}/></Link></div><form action={submitSave} className="mt-6"><input type="hidden" name="locale" value={locale}/><input type="hidden" name="answers" value={JSON.stringify(answers)}/>{organizations.length === 1 ? <input type="hidden" name="organizationId" value={organizations[0]!.id}/> : <label className="grid gap-2 text-start"><strong>{locale === "fr" ? "Entreprise concernée" : "المؤسسة المعنية"}</strong><select name="organizationId" required className="min-h-11 rounded-md border bg-white px-3 text-slate-950">{organizations.map((organization) => <option key={organization.id} value={organization.id}>{organization.name}</option>)}</select></label>}<p className="mt-3">{locale === "fr" ? "L’enregistrement conserve uniquement cette orientation publique, distincte du diagnostic versionné." : "يحفظ التسجيل هذا التوجيه العام فقط، وهو منفصل عن التشخيص ذي الإصدار."}</p>{saveState.status === "error" ? <p role="alert" className="mt-3 text-red-700">{saveState.reason === "FORBIDDEN" ? locale === "fr" ? "Vous n’avez plus l’autorisation d’enregistrer pour cette entreprise." : "لم يعد لديكم إذن الحفظ لهذه المؤسسة." : locale === "fr" ? "L’enregistrement a échoué. Vos réponses restent disponibles sur cet appareil." : "تعذر الحفظ. ما زالت إجاباتكم متاحة على هذا الجهاز."}</p> : null}{saveState.status === "success" ? <p role="status" className="mt-3"><CheckCircle2 aria-hidden="true" className="inline" size={18}/> {locale === "fr" ? "Orientation enregistrée." : "تم حفظ التوجيه."} <Link className="font-semibold underline" href={questionnaireHref}>{copy.continueQuestionnaire}</Link></p> : <div className="journey-actions mt-4"><button type="submit" className="journey-secondary" disabled={savePending || !completeAnswers}>{savePending ? locale === "fr" ? "Enregistrement…" : "جارٍ الحفظ…" : copy.saveOrientation}</button></div>}</form></div> : <div className="journey-login-note"><p>{locale === "fr" ? "Votre compte n’a aucune organisation Client autorisée pour cet enregistrement." : "لا يحتوي حسابكم على مؤسسة عميلة مخولة لهذا الحفظ."}</p><div className="journey-actions mt-3"><button type="button" className="journey-secondary" onClick={onEdit}>{copy.restart}</button><Link className="inline-flex font-semibold underline" href={`/${locale}/organisation?role=client`}>{locale === "fr" ? "Configurer mon organisation" : "إعداد مؤسستي"}</Link></div></div>}<div className="journey-links"><Link href={`/${locale}/besoin?source=diagnostic`}>{copy.prepare}</Link><Link href={`/${locale}/besoin?source=diagnostic&priority=${encodeURIComponent(priorities[0] ?? "")}`}>{copy.assist}</Link><button type="button" onClick={onErase}><Trash2 aria-hidden="true" size={15}/>{copy.erase}</button></div>{!storageAvailable ? <p role="status" className="journey-login-note">{locale === "fr" ? "Ce bilan n’est pas sauvegardé sur cet appareil." : "هذا التقييم غير محفوظ على هذا الجهاز."}</p> : null}
  </section></main>;
}
