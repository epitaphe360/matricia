"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, ArrowLeft, ArrowRight, CheckCircle2, CircleHelp, Sparkles, Trash2 } from "lucide-react";
import type { Locale } from "@/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";

type Stored = { expiresAt: number; step: number; answers: Record<number, string | string[]>; locale: Locale };
const storageKey = "matricia.public-diagnostic";
const initial = (locale: Locale): Stored => ({ expiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000, step: 0, answers: {}, locale });

export function PrediagnosticFlow({ locale }: { locale: Locale }) {
  const copy = getPublicJourneyCopy(locale).diagnostic;
  const [state, setState] = useState<Stored>(() => initial(locale));
  const [loaded, setLoaded] = useState(false);
  useEffect(() => {
    const timer = window.setTimeout(() => {
      const raw = window.localStorage.getItem(storageKey) ?? window.sessionStorage.getItem(storageKey) ?? window.localStorage.getItem("matricia.public-diagnostic." + locale);
      if (raw) try { const parsed = JSON.parse(raw) as Stored; if (parsed.expiresAt > Date.now()) setState(translateStored(parsed, locale)); } catch {}
      setLoaded(true);
    }, 0);
    return () => window.clearTimeout(timer);
  }, [locale]);
  useEffect(() => { if (loaded) window.localStorage.setItem(storageKey, JSON.stringify(state)); }, [state, loaded]);
  const setAnswer = (value: string | string[]) => setState(current => ({ ...current, answers: { ...current.answers, [current.step]: value } }));
  if (!loaded) return <main id="contenu-principal" className="journey-shell" aria-busy="true" />;
  if (state.step >= copy.questions.length) return <Result locale={locale} answers={state.answers} onRestart={() => setState(initial(locale))} onErase={() => { window.localStorage.removeItem(storageKey); setState(initial(locale)); }} />;
  const question = copy.questions[state.step];
  const isLast = state.step === copy.questions.length - 1;
  const answer = state.answers[state.step];
  const canProceed = question[2].length > 0 ? Boolean(Array.isArray(answer) ? answer.length : answer) : typeof answer === "string" && answer.trim().length >= 3;
  return <main id="contenu-principal" className="journey-shell" dir={locale === "ar" ? "rtl" : "ltr"}>
    <div className="journey-card">
      <p className="journey-eyebrow">{copy.eyebrow}</p><p className="journey-progress" aria-live="polite">{copy.progress(state.step + 1, copy.questions.length)}</p>
      <div className="journey-progressbar"><span style={{ width: ((state.step + 1) / copy.questions.length) * 100 + "%" }} /></div>
      <h1 id="diagnostic-question">{question[0]}</h1><p className="journey-intro">{question[1]}</p>
      {question[2].length > 0 ? <Choices label={String(question[0])} choices={question[2] as readonly string[]} value={answer} multi={state.step === 0} onChange={setAnswer} /> : <textarea aria-labelledby="diagnostic-question" className="journey-textarea" autoFocus value={typeof answer === "string" ? answer : ""} onChange={event => setAnswer(event.target.value.slice(0, 500))} rows={5} maxLength={500} />}
      <div className="journey-actions">
        {state.step > 0 ? <button type="button" className="journey-secondary" onClick={() => setState(current => ({ ...current, step: current.step - 1 }))}><ArrowLeft aria-hidden="true" size={18} />{copy.back}</button> : <Link className="journey-secondary" href={"/" + locale}>{copy.back}</Link>}
        <button type="button" className="journey-primary" disabled={!canProceed} onClick={() => setState(current => ({ ...current, step: current.step + 1 }))}>{isLast ? copy.result : copy.next}<ArrowRight aria-hidden="true" size={18} /></button>
      </div>
    </div>
  </main>;
}

function translateStored(stored: Stored, locale: Locale): Stored {
  if (!stored.locale || stored.locale === locale) return { ...stored, locale };
  const source = getPublicJourneyCopy(stored.locale).diagnostic.questions;
  const target = getPublicJourneyCopy(locale).diagnostic.questions;
  const translated: Record<number, string | string[]> = {};
  for (const [key, raw] of Object.entries(stored.answers)) {
    const index = Number(key); const sourceChoices = source[index]?.[2] ?? []; const targetChoices = target[index]?.[2] ?? [];
    const convert = (value: string) => { const choiceIndex = sourceChoices.indexOf(value); return choiceIndex >= 0 ? targetChoices[choiceIndex] ?? value : value; };
    translated[index] = Array.isArray(raw) ? raw.map(convert) : convert(raw);
  }
  return { ...stored, locale, answers: translated };
}

function Choices({ label, choices, value, multi, onChange }: { label: string; choices: readonly string[]; value: string | string[] | undefined; multi: boolean; onChange: (value: string | string[]) => void }) {
  const selected = Array.isArray(value) ? value : value ? [value] : [];
  return <div className="journey-choices" role={multi ? "group" : "radiogroup"} aria-label={label}>
    {choices.map(choice => <button key={choice} type="button" role={multi ? undefined : "radio"} aria-pressed={multi ? selected.includes(choice) : undefined} aria-checked={multi ? undefined : selected.includes(choice)} className={selected.includes(choice) ? "is-selected" : ""} onClick={() => {
      if (!multi) return onChange(choice);
      onChange(selected.includes(choice) ? selected.filter(item => item !== choice) : [...selected, choice]);
    }}><span>{choice}</span><CheckCircle2 aria-hidden="true" size={20} /></button>)}
  </div>;
}

function Result({ locale, answers, onRestart, onErase }: { locale: Locale; answers: Record<number, string | string[]>; onRestart: () => void; onErase: () => void }) {
  const copy = getPublicJourneyCopy(locale).diagnostic;
  const priorities = useMemo(() => {
    const items: (keyof typeof copy.priorities)[] = [];
    const organization = answers[3]; const sales = answers[4]; const security = answers[5];
    if (organization === "Non" || organization === "Partiellement" || organization === "لا" || organization === "جزئياً") items.push("organization");
    else if (organization === "Je ne sais pas" || organization === "لا أعلم") items.push("verify");
    if (sales === "Tableaux manuels" || sales === "Au cas par cas" || sales === "جداول يدوية" || sales === "كل حالة على حدة") items.push("sales");
    else if (sales === "Je ne sais pas" || sales === "لا أعلم") items.push("verify");
    if (security === "Non" || security === "لا") items.push("security");
    else if (security === "Je ne sais pas" || security === "لا أعلم") items.push("verify");
    return [...new Set(items)].slice(0, 3).length ? [...new Set(items)].slice(0, 3) : ["verify"] as (keyof typeof copy.priorities)[];
  }, [answers, copy]);
  const next = "/" + locale + "/connexion?next=" + encodeURIComponent("/" + locale + "/diagnostic?resume=1");
  const kinds = { organization: "opportunity", sales: "declared", security: "risk", verify: "verify" } as const;
  return <main id="contenu-principal" className="journey-shell" dir={locale === "ar" ? "rtl" : "ltr"}><section className="journey-card journey-result">
    <p className="journey-eyebrow">{copy.eyebrow}</p><h1>{copy.resultTitle}</h1><p className="journey-based">{copy.basedOn}</p>
    <div className="journey-scope"><div><strong>{copy.scope}</strong><span>{locale === "fr" ? copy.questions.length + " questions déclaratives" : copy.questions.length + " أسئلة تصريحية"}</span></div><div><strong>{copy.limits}</strong><span>{locale === "fr" ? "Ce bilan ne couvre pas les sujets non abordés ni une conformité légale." : "لا يغطي هذا التقييم المواضيع غير المطروحة ولا يشكل إثبات امتثال قانوني."}</span></div></div>
    <ol className="journey-priorities">{priorities.map((key, index) => { const item = copy.priorities[key]; const kind = kinds[key]; const Icon = kind === "risk" ? AlertTriangle : kind === "verify" ? CircleHelp : Sparkles; return <li key={key} data-kind={kind}><span>0{index + 1}</span><small className="journey-kind"><Icon aria-hidden="true" size={15}/>{copy.kindLabels[kind]}</small><h2>{item[0]}</h2><p>{item[1]}</p><strong>{item[2]}</strong></li>; })}</ol>
    <p className="journey-login-note">{copy.loginNote}</p><div className="journey-actions"><button type="button" className="journey-secondary" onClick={onRestart}>{copy.restart}</button><Link className="journey-primary" href={next}>{copy.save}<ArrowRight aria-hidden="true" size={18} /></Link></div>
    <div className="journey-links"><Link href={"/" + locale + "/besoin"}>{copy.prepare}</Link><Link href={"/" + locale + "/besoin"}>{copy.assist}</Link><button type="button" onClick={onErase}><Trash2 aria-hidden="true" size={15} />{copy.erase}</button></div>
  </section></main>;
}
