"use client";

import Link from "next/link";
import { use, useEffect, useState } from "react";
import { ArrowRight, CheckCircle2 } from "lucide-react";
import type { Locale } from "@/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";

export default function ProviderEntry({ params }: { params: Promise<{ locale: Locale }> }) {
  const { locale } = use(params);
  const [activity, setActivity] = useState("");
  const copy = getPublicJourneyCopy(locale).provider;
  const next = `/${locale}/connexion?next=${encodeURIComponent(`/${locale}/sous-traitant/qualification`)}`;

  useEffect(() => {
    const timer = window.setTimeout(() => setActivity(localStorage.getItem("matricia.provider-intent") ?? localStorage.getItem(`matricia.provider-intent.${locale}`) ?? ""), 0);
    return () => window.clearTimeout(timer);
  }, [locale]);

  return <main id="contenu-principal" className="journey-shell">
    <section className="journey-card">
      <p className="journey-eyebrow">{copy.eyebrow}</p>
      <h1>{copy.title}</h1>
      <p className="journey-intro">{copy.intro}</p>
      <ol className="journey-provider-steps" aria-label={copy.eyebrow}>
        {copy.steps.map((step, index) => <li key={step}><span>0{index + 1}</span><CheckCircle2 aria-hidden="true" size={17}/>{step}</li>)}
      </ol>
      <label className="journey-label" htmlFor="provider-activity">{copy.activity}</label>
      <textarea id="provider-activity" className="journey-textarea" value={activity} placeholder={copy.placeholder} onChange={event => {
        const value = event.target.value.slice(0, 1200);
        setActivity(value);
        localStorage.setItem("matricia.provider-intent", value);
      }} rows={6} maxLength={1200}/>
      <p className="journey-login-note">{copy.note}</p>
      <div className="journey-actions">
        <Link className="journey-secondary" href={next}>{copy.existing}</Link>
        <Link className="journey-primary" href={next}>{copy.begin}<ArrowRight size={18} aria-hidden="true" /></Link>
      </div>
    </section>
  </main>;
}
