"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { ArrowRight, Pencil } from "lucide-react";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const objectives = {
  fr: ["Clarifier une situation", "Corriger un dysfonctionnement", "Lancer un projet", "Mettre en conformité", "Former les équipes", "Autre objectif"],
  ar: ["توضيح وضع", "معالجة خلل", "إطلاق مشروع", "تحقيق الامتثال", "تكوين الفرق", "هدف آخر"],
} as const;
const delays = {
  fr: ["Moins d’un mois", "1 à 3 mois", "3 à 6 mois", "Plus de 6 mois", "À préciser"],
  ar: ["أقل من شهر", "من شهر إلى 3 أشهر", "من 3 إلى 6 أشهر", "أكثر من 6 أشهر", "يُحدَّد لاحقاً"],
} as const;
const contexts = {
  fr: ["TPE / indépendant", "PME", "Grande organisation", "Administration / association", "En création"],
  ar: ["مقاولة صغيرة جداً / مستقل", "مقاولة صغيرة ومتوسطة", "منظمة كبيرة", "إدارة / جمعية", "في طور التأسيس"],
} as const;

export function ServiceNeedComposer({
  locale,
  serviceCode,
  serviceName,
  description,
}: {
  locale: Locale;
  serviceCode: string;
  serviceName: string;
  description: string;
}) {
  const fr = locale === "fr";
  const [objective, setObjective] = useState("");
  const [delay, setDelay] = useState("");
  const [context, setContext] = useState("");
  const [notes, setNotes] = useState("");
  const summary = useMemo(
    () => [serviceName, objective, delay, context, notes.trim()].filter(Boolean).join(" — ").slice(0, 500),
    [context, delay, notes, objective, serviceName],
  );
  const params = new URLSearchParams({ serviceCode, service: serviceName, library: serviceCode.split("-")[0] ?? "" });
  if (summary) params.set("q", summary);
  const href = `/${locale}/besoin?${params.toString()}`;
  const missing = [
    objective ? null : fr ? "Objectif" : "الهدف",
    delay ? null : fr ? "Délai" : "الأجل",
    context ? null : fr ? "Contexte" : "السياق",
  ].filter(Boolean);

  return (
    <section className="mt-8 grid gap-6 lg:grid-cols-[1.15fr_.85fr]">
      <article className="public-card max-w-none">
        <h2>{fr ? "Décrivez votre besoin" : "صفوا احتياجكم"}</h2>
        <p className="public-muted mt-2">{fr ? "Sélectionnez les éléments qui correspondent le mieux à votre situation." : "اختاروا العناصر الأقرب لوضعكم."}</p>
        <p className="mt-3 text-sm text-slate-600" lang="fr">{description}</p>
        <div className="public-form-grid mt-6">
          <label className="block font-medium">
            {fr ? "Votre objectif" : "هدفكم"} *
            <select value={objective} onChange={(event) => setObjective(event.target.value)} className="mt-2 w-full">
              <option value="">{fr ? "Choisir un objectif" : "اختاروا هدفاً"}</option>
              {objectives[locale].map((item) => <option key={item} value={item}>{item}</option>)}
            </select>
          </label>
          <label className="block font-medium">
            {fr ? "Votre délai souhaité" : "الأجل المرغوب"} *
            <select value={delay} onChange={(event) => setDelay(event.target.value)} className="mt-2 w-full">
              <option value="">{fr ? "Sélectionner un délai" : "اختاروا أجلاً"}</option>
              {delays[locale].map((item) => <option key={item} value={item}>{item}</option>)}
            </select>
          </label>
          <label className="block font-medium">
            {fr ? "Votre contexte" : "سياقكم"}
            <select value={context} onChange={(event) => setContext(event.target.value)} className="mt-2 w-full">
              <option value="">{fr ? "Sélectionner un contexte" : "اختاروا سياقاً"}</option>
              {contexts[locale].map((item) => <option key={item} value={item}>{item}</option>)}
            </select>
          </label>
          <label className="block font-medium">
            {fr ? "Précisions utiles (optionnel)" : "توضيحات مفيدة (اختياري)"}
            <textarea value={notes} maxLength={500} rows={4} onChange={(event) => setNotes(event.target.value.slice(0, 500))} placeholder={fr ? "Décrivez brièvement votre situation…" : "صفوا وضعكم باختصار…"} className="mt-2 w-full" />
            <span className="journey-charcount">{notes.length}/500</span>
          </label>
        </div>
        <p className="mt-4 text-sm font-semibold">{fr ? "Votre besoin se structure au fur et à mesure" : "يُنظَّم احتياجكم تدريجياً"}</p>
        <div className="journey-need-tags">
          <span className={`inline-flex min-h-10 items-center rounded-full border px-3 text-sm ${objective ? "border-[#6d3cc7] bg-[#f3eaff]" : "border-[#eadfce]"}`}>{fr ? "Objectif" : "الهدف"} : {objective || "—"}</span>
          <span className={`inline-flex min-h-10 items-center rounded-full border px-3 text-sm ${delay ? "border-[#6d3cc7] bg-[#f3eaff]" : "border-[#eadfce]"}`}>{fr ? "Délai" : "الأجل"} : {delay || "—"}</span>
          <span className={`inline-flex min-h-10 items-center rounded-full border px-3 text-sm ${context ? "border-[#6d3cc7] bg-[#f3eaff]" : "border-[#eadfce]"}`}>{fr ? "Contexte" : "السياق"} : {context || "—"}</span>
        </div>
      </article>
      <aside className="journey-understood">
        <h2>{fr ? "Ce que Matricia a compris" : "ما فهمته ماتريسيا"}</h2>
        <p className="public-muted mt-2">{fr ? "Voici la synthèse de votre besoin. Vous pourrez la modifier avant de continuer." : "هذا ملخص احتياجكم. يمكنكم التعديل قبل المتابعة."}</p>
        <p className="mt-4 text-sm font-semibold text-[#1a2340]" lang="fr">{serviceName}</p>
        <p className="mt-2 text-sm text-slate-600">{missing.length ? (fr ? `Aucun élément sélectionné pour le moment. ${missing.join(", ")}.` : `لا عنصر محدد بعد. ${missing.join("، ")}.`) : summary}</p>
        <div className="journey-actions">
          <Link className="journey-secondary" href={`/${locale}/besoin`}><Pencil size={16} aria-hidden="true" />{fr ? "Modifier" : "تعديل"}</Link>
          <Link className="journey-primary" href={href}>{fr ? "Continuer" : "متابعة"}<ArrowRight className="rtl-mirror" size={16} aria-hidden="true" /></Link>
        </div>
        <p className="mt-6 text-sm text-slate-600">{fr ? "Aucun professionnel n’est contacté sans votre confirmation." : "لا يُتصل بأي مهني دون تأكيدكم."}</p>
      </aside>
    </section>
  );
}
