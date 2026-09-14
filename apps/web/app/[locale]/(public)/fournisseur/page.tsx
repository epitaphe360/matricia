"use client";
import Link from "next/link";
import { use, useState } from "react";
import { ArrowRight } from "lucide-react";
import type { Locale } from "@/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";
export default function ProviderEntry({ params }: { params: Promise<{ locale: Locale }> }) {
  const { locale } = use(params); const [activity, setActivity] = useState(""); const c = getPublicJourneyCopy(locale).provider;
  const next = "/" + locale + "/connexion?next=" + encodeURIComponent("/" + locale + "/sous-traitant/qualification");
  return <main id="contenu-principal" className="journey-shell"><section className="journey-card"><p className="journey-eyebrow">{c.eyebrow}</p><h1>{c.title}</h1><p className="journey-intro">{c.intro}</p><label className="journey-label" htmlFor="provider-activity">{c.activity}</label><textarea id="provider-activity" className="journey-textarea" value={activity} placeholder={c.placeholder} onChange={event => { const value = event.target.value.slice(0, 1200); setActivity(value); localStorage.setItem("matricia.provider-intent." + locale, value); }} rows={6} maxLength={1200}/><p className="journey-login-note">{c.note}</p><div className="journey-actions"><Link className="journey-secondary" href={next}>{c.existing}</Link><Link className="journey-primary" href={next}>{c.begin}<ArrowRight size={18} aria-hidden="true" /></Link></div></section></main>;
}
