"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight } from "lucide-react";
import type { Locale } from "@/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";

type Draft = { need: string; location: string; timing: string; constraints: string; expiresAt: number };
const storageKey = "matricia.public-need";
const retentionMs = 7 * 86_400_000;

export function NeedFlow({ locale, initialNeed = "" }: { locale: Locale; initialNeed?: string }) {
  const copy = getPublicJourneyCopy(locale).need;
  const [step, setStep] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const [draft, setDraft] = useState<Draft>({ need: initialNeed, location: "", timing: "", constraints: "", expiresAt: 0 });

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const raw = localStorage.getItem(storageKey) ?? localStorage.getItem(`matricia.public-need.${locale}`);
      let next: Draft = { need: initialNeed, location: "", timing: "", constraints: "", expiresAt: Date.now() + retentionMs };
      if (raw) try {
        const saved = JSON.parse(raw) as Draft;
        if (saved.expiresAt > Date.now()) next = saved;
      } catch {}
      setDraft(next);
      setLoaded(true);
    }, 0);
    return () => window.clearTimeout(timer);
  }, [initialNeed, locale]);

  useEffect(() => {
    if (loaded) localStorage.setItem(storageKey, JSON.stringify(draft));
  }, [draft, loaded]);

  const fields = [
    { label: copy.prompt, name: "need" as const, placeholder: copy.placeholder, required: true },
    { label: copy.location, name: "location" as const, placeholder: copy.optional, required: false },
    { label: copy.timing, name: "timing" as const, placeholder: copy.optional, required: false },
    { label: copy.constraints, name: "constraints" as const, placeholder: copy.optional, required: false },
  ];

  if (!loaded) return <main id="contenu-principal" className="journey-shell" aria-busy="true" />;
  if (step === fields.length) return <main id="contenu-principal" className="journey-shell"><section className="journey-card journey-result">
    <p className="journey-eyebrow">{copy.eyebrow}</p><h1>{copy.readyTitle}</h1><p className="journey-intro">{copy.readyText}</p><p className="journey-login-note">{copy.localOnly}</p>
    <div className="journey-actions"><Link className="journey-secondary" href={`/${locale}/diagnostic`}>{copy.diagnostic}</Link><Link className="journey-primary" href={`/${locale}/connexion?next=${encodeURIComponent(`/${locale}/besoin?resume=1`)}`}>{copy.login}<ArrowRight size={18} aria-hidden="true" /></Link></div>
  </section></main>;

  const field = fields[step];
  const value = draft[field.name];
  const tooShort = field.required && value.length > 0 && value.trim().length < 10;
  return <main id="contenu-principal" className="journey-shell"><section className="journey-card">
    <p className="journey-eyebrow">{copy.eyebrow}</p><p className="journey-progress" aria-live="polite">{step + 1} / {fields.length}</p>
    <h1 id="need-question">{field.label}</h1>
    <textarea aria-labelledby="need-question" aria-describedby={tooShort ? "need-guidance" : undefined} className="journey-textarea" autoFocus value={value} placeholder={field.placeholder} onChange={event => setDraft(current => ({ ...current, [field.name]: event.target.value.slice(0, 1200), expiresAt: Date.now() + retentionMs }))} rows={6} maxLength={1200}/>
    <p id="need-guidance" role={tooShort ? "status" : undefined} className="journey-field-help">{tooShort ? (locale === "fr" ? "Décrivez votre besoin en au moins 10 caractères." : "صف حاجتك في 10 أحرف على الأقل.") : ""}</p>
    <div className="journey-actions">{step ? <button className="journey-secondary" type="button" onClick={() => setStep(step - 1)}>{copy.back}</button> : <Link className="journey-secondary" href={`/${locale}`}>{copy.back}</Link>}<button className="journey-primary" type="button" disabled={field.required && value.trim().length < 10} onClick={() => setStep(step + 1)}>{copy.continue}<ArrowRight size={18} aria-hidden="true" /></button></div>
  </section></main>;
}
