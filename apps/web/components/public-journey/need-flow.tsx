"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight } from "lucide-react";
import type { Locale } from "@/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";
type Draft = { need: string; location: string; timing: string; constraints: string; expiresAt: number };
const key = (locale: Locale) => "matricia.public-need." + locale;
export function NeedFlow({ locale, initialNeed = "" }: { locale: Locale; initialNeed?: string }) {
  const c = getPublicJourneyCopy(locale).need; const [step, setStep] = useState(0); const [draft, setDraft] = useState<Draft>({ need: initialNeed, location: "", timing: "", constraints: "", expiresAt: Date.now() + 7 * 86400000 });
  useEffect(() => { const raw = localStorage.getItem(key(locale)); if (raw) try { const saved = JSON.parse(raw) as Draft; if (saved.expiresAt > Date.now()) setDraft(saved); } catch {} }, [locale]);
  useEffect(() => { localStorage.setItem(key(locale), JSON.stringify(draft)); }, [draft, locale]);
  const fields = [{ label: c.prompt, name: "need" as const, placeholder: c.placeholder, required: true }, { label: c.location, name: "location" as const, placeholder: c.optional, required: false }, { label: c.timing, name: "timing" as const, placeholder: c.optional, required: false }, { label: c.constraints, name: "constraints" as const, placeholder: c.optional, required: false }];
  if (step === fields.length) return <main id="contenu-principal" className="journey-shell"><section className="journey-card journey-result"><p className="journey-eyebrow">{c.eyebrow}</p><h1>{c.readyTitle}</h1><p className="journey-intro">{c.readyText}</p><p className="journey-login-note">{c.localOnly}</p><div className="journey-actions"><Link className="journey-secondary" href={"/" + locale + "/diagnostic"}>{c.diagnostic}</Link><Link className="journey-primary" href={"/" + locale + "/connexion?next=" + encodeURIComponent("/" + locale + "/besoin?resume=1")}>{c.login}<ArrowRight size={18} aria-hidden="true" /></Link></div></section></main>;
  const field = fields[step]; const value = draft[field.name];
  return <main id="contenu-principal" className="journey-shell"><section className="journey-card"><p className="journey-eyebrow">{c.eyebrow}</p><p className="journey-progress">{step + 1 + " / " + fields.length}</p><h1>{field.label}</h1><textarea className="journey-textarea" autoFocus value={value} placeholder={field.placeholder} onChange={event => setDraft(current => ({ ...current, [field.name]: event.target.value.slice(0, 1200) }))} rows={6} maxLength={1200}/><div className="journey-actions">{step ? <button className="journey-secondary" type="button" onClick={() => setStep(step - 1)}>{c.back}</button> : <Link className="journey-secondary" href={"/" + locale}>{c.back}</Link>}<button className="journey-primary" type="button" disabled={field.required && value.trim().length < 10} onClick={() => setStep(step + 1)}>{c.continue}<ArrowRight size={18} aria-hidden="true" /></button></div></section></main>;
}
