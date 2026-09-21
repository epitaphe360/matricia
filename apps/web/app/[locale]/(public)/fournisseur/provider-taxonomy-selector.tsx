"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { ArrowRight, Check, Search, X } from "lucide-react";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import {
  createProviderIntentDraft,
  MAX_PROVIDER_SERVICES,
  parseProviderIntentDraft,
  PROVIDER_INTENT_KEY,
  PROVIDER_INTENT_LEGACY_KEY,
  summarizeProviderIntent,
  type PublicProviderCategory,
} from "@/modules/public/data/provider-intent/model";
import { getPublicProviderIntentMessages } from "@/modules/public/data/provider-intent/messages";

type Library = { code: string; name: string; categories: PublicProviderCategory[] };

export function ProviderTaxonomySelector({ locale, libraries }: { locale: Locale; libraries: Library[] }) {
  const copy = getPublicProviderIntentMessages(locale);
  const [libraryCode, setLibraryCode] = useState(libraries[0]?.code ?? "");
  const [query, setQuery] = useState("");
  const [serviceCodes, setServiceCodes] = useState<string[]>([]);
  const [otherEnabled, setOtherEnabled] = useState(false);
  const [otherService, setOtherService] = useState("");
  const [activity, setActivity] = useState("");
  const [hydrated, setHydrated] = useState(false);
  const [storageAvailable, setStorageAvailable] = useState(true);

  const allServices = useMemo(() => libraries.flatMap((library) => library.categories.flatMap((category) => category.services)), [libraries]);
  const serviceByCode = useMemo(() => new Map(allServices.map((service) => [service.code, service])), [allServices]);
  const normalizedQuery = query.trim().toLocaleLowerCase(locale === "ar" ? "ar" : "fr");
  const visibleCategories = (normalizedQuery
    ? [{ code: "SEARCH", name: copy.search, services: allServices.filter((service) => `${service.name} ${service.description}`.toLocaleLowerCase("fr").includes(normalizedQuery)).slice(0, 20) }]
    : libraries.find((library) => library.code === libraryCode)?.categories ?? []);
  const visibleServiceCount = visibleCategories.reduce((count, category) => count + category.services.length, 0);
  const hasIntent = serviceCodes.length > 0 || (otherEnabled && otherService.trim().length >= 3);
  const destination = `/${locale}/sous-traitant/qualification`;
  const registration = `/${locale}/connexion?mode=inscription&role=fournisseur&next=${encodeURIComponent(destination)}`;
  const existingAccount = `/${locale}/connexion?next=${encodeURIComponent(destination)}`;

  useEffect(() => {
    const timer = window.setTimeout(() => {
      try {
        const draft = parseProviderIntentDraft(window.localStorage.getItem(PROVIDER_INTENT_KEY));
        if (draft) {
          setServiceCodes(draft.serviceCodes);
          setOtherService(draft.otherService);
          setOtherEnabled(Boolean(draft.otherService));
          const first = serviceByCode.get(draft.serviceCodes[0] ?? "");
          if (first) setLibraryCode(first.libraryCode);
        } else {
          window.localStorage.removeItem(PROVIDER_INTENT_KEY);
        }
      } catch {
        setStorageAvailable(false);
      } finally {
        setHydrated(true);
      }
    }, 0);
    return () => window.clearTimeout(timer);
  }, [serviceByCode]);

  useEffect(() => {
    if (!hydrated) return;
    const timer = window.setTimeout(() => {
      const draft = createProviderIntentDraft({ serviceCodes, otherService: otherEnabled ? otherService : "" });
      try {
        window.localStorage.setItem(PROVIDER_INTENT_KEY, JSON.stringify(draft));
        // Compatibility bridge: the authenticated qualification screen currently consumes this bounded summary.
        window.localStorage.setItem(PROVIDER_INTENT_LEGACY_KEY, summarizeProviderIntent(draft, locale));
        setStorageAvailable(true);
      } catch {
        setStorageAvailable(false);
      }
    }, 250);
    return () => window.clearTimeout(timer);
  }, [hydrated, locale, otherEnabled, otherService, serviceCodes]);

  function toggleService(code: string) {
    setServiceCodes((current) => current.includes(code) ? current.filter((item) => item !== code)
      : current.length < MAX_PROVIDER_SERVICES ? [...current, code] : current);
  }

  return <section aria-labelledby="provider-taxonomy-title" className="mt-8 min-w-0 max-w-full rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:p-6">
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div><h2 id="provider-taxonomy-title" className="text-xl font-semibold text-[#0b1739]">{copy.title}</h2><p className="mt-1 text-sm text-slate-600">{serviceCodes.length}/{MAX_PROVIDER_SERVICES}</p></div>
      {hydrated && storageAvailable ? <p role="status" className="text-sm text-emerald-700">{copy.saved}</p> : null}
    </div>

    <div className="journey-provider-board">
      <label className="grid gap-2">
        <span className="text-sm font-semibold text-slate-700">{locale === "ar" ? "صفوا نشاطكم باختصار" : "Décrivez brièvement votre activité"}</span>
        <textarea value={activity} onChange={(event) => setActivity(event.target.value.slice(0, 300))} maxLength={300} rows={6} className="min-h-36 w-full rounded-xl border border-slate-300 bg-white p-3" placeholder={locale === "ar" ? "مثال: أشغال النجارة الداخلية والخارجية…" : "Ex. : Travaux de menuiserie intérieure et extérieure…"} />
        <span className="text-xs text-slate-500">{activity.length}/300</span>
      </label>
    <fieldset className="mt-5 min-w-0"><legend className="text-sm font-semibold text-slate-700">{copy.chooseDomain}</legend>
      <div className="mt-2 flex max-w-full gap-2 overflow-x-auto pb-2">{libraries.map((library) => <button key={library.code} type="button" onClick={() => setLibraryCode(library.code)} aria-pressed={libraryCode === library.code} className="min-h-11 shrink-0 rounded-full border border-slate-300 bg-white px-4 text-sm font-semibold text-slate-700 aria-pressed:border-blue-700 aria-pressed:bg-blue-700 aria-pressed:text-white">{library.name}</button>)}</div>
    </fieldset>

    <div>

    <label htmlFor="provider-service-search" className="mt-4 block text-sm font-semibold text-slate-700">{copy.search}</label>
    <div className="relative mt-2"><Search aria-hidden="true" className="pointer-events-none absolute start-3 top-3.5 size-4 text-slate-500"/><input id="provider-service-search" value={query} onChange={(event) => setQuery(event.target.value.slice(0, 120))} className="min-h-11 w-full rounded-xl border border-slate-300 bg-white ps-10 pe-3" type="search" maxLength={120}/></div>

    <div className="mt-4 max-h-96 space-y-5 overflow-y-auto pe-1" aria-live="polite">{visibleCategories.map((category) => <section key={category.code} aria-labelledby={`provider-category-${category.code}`}><h3 id={`provider-category-${category.code}`} className="sticky top-0 bg-slate-50 py-2 text-sm font-semibold text-slate-700" lang="fr">{category.name}</h3><div className="grid gap-2 sm:grid-cols-2">{category.services.map((service) => {
      const checked = serviceCodes.includes(service.code);
      return <label key={service.code} className="flex min-h-14 min-w-0 cursor-pointer items-start gap-3 rounded-xl border border-slate-200 bg-white p-3 hover:border-blue-300"><input type="checkbox" checked={checked} onChange={() => toggleService(service.code)} disabled={!checked && serviceCodes.length >= MAX_PROVIDER_SERVICES} className="mt-0.5 size-5 accent-blue-700"/><span className="min-w-0"><span className="block break-words text-sm font-semibold text-slate-900" lang="fr">{service.name}</span><span className="mt-1 line-clamp-2 block break-words text-xs leading-5 text-slate-500" lang="fr">{service.description}</span></span></label>;
    })}</div></section>)}</div>
    {visibleServiceCount === 0 ? <p className="mt-4 rounded-xl bg-white p-4 text-sm text-slate-600">{copy.noResult}</p> : null}
    {serviceCodes.length >= MAX_PROVIDER_SERVICES ? <p role="status" className="mt-3 text-sm text-amber-800">{copy.limit}</p> : null}

    {serviceCodes.length > 0 ? <div className="mt-5 min-w-0"><h3 className="text-sm font-semibold text-slate-700">{copy.selected}</h3><ul className="mt-2 flex min-w-0 max-w-full flex-wrap gap-2">{serviceCodes.map((code) => <li className="min-w-0 max-w-full" key={code}><button type="button" onClick={() => toggleService(code)} className="inline-flex min-h-11 max-w-full items-center gap-2 rounded-full bg-blue-100 px-3 text-sm font-medium text-blue-950"><Check aria-hidden="true" className="size-4 shrink-0"/><span className="min-w-0 break-words" lang="fr">{serviceByCode.get(code)?.name ?? code}</span><X aria-hidden="true" className="size-4 shrink-0"/></button></li>)}</ul></div> : null}

    <label className="mt-5 flex min-h-11 items-center gap-3"><input type="checkbox" checked={otherEnabled} onChange={(event) => setOtherEnabled(event.target.checked)} className="size-5 accent-blue-700"/><span className="font-medium text-slate-800">{copy.otherToggle}</span></label>
    {otherEnabled ? <div className="mt-2"><label htmlFor="provider-other-service" className="text-sm font-semibold text-slate-700">{copy.otherLabel}</label><textarea id="provider-other-service" value={otherService} onChange={(event) => setOtherService(event.target.value.slice(0, 500))} rows={3} maxLength={500} className="mt-2 w-full rounded-xl border border-slate-300 bg-white p-3"/></div> : null}
    {!storageAvailable ? <p role="alert" className="mt-3 text-sm text-amber-800">{copy.storageUnavailable}</p> : null}
    {!hasIntent ? <p className="mt-4 text-sm text-slate-600">{copy.empty}</p> : null}
    <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end"><Link className="inline-flex min-h-11 items-center justify-center rounded-xl border border-slate-300 bg-white px-5 font-semibold text-slate-800" href={existingAccount}>{copy.existing}</Link><Link aria-disabled={!hasIntent} tabIndex={hasIntent ? undefined : -1} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-blue-700 px-5 font-semibold text-white aria-disabled:pointer-events-none aria-disabled:opacity-50" href={registration}>{copy.continue}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180"/></Link></div>
    </div>
    </div>
  </section>;
}
