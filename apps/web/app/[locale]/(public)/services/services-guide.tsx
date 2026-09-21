"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { ArrowRight, Search } from "lucide-react";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { PublicProviderCategory } from "@/modules/public/data/provider-intent/model";
import { getPublicServicesGuideMessages } from "@/modules/public/data/provider-intent/messages";

type Library = { code: string; name: string; categories: PublicProviderCategory[] };

export function ServicesGuide({ locale, libraries, initialQuery, initialLibrary }: { locale: Locale; libraries: Library[]; initialQuery: string; initialLibrary: string }) {
  const copy = getPublicServicesGuideMessages(locale);
  const validInitialLibrary = libraries.some((library) => library.code === initialLibrary) ? initialLibrary : libraries[0]?.code ?? "";
  const [libraryCode, setLibraryCode] = useState(validInitialLibrary);
  const [query, setQuery] = useState(initialQuery);
  const allServices = useMemo(() => libraries.flatMap((library) => library.categories.flatMap((category) => category.services)), [libraries]);
  const normalizedQuery = query.trim().toLocaleLowerCase(locale === "ar" ? "ar" : "fr");
  const categories = normalizedQuery
    ? [{ code: "SEARCH", name: copy.results, services: allServices.filter((service) => `${service.name} ${service.description}`.toLocaleLowerCase("fr").includes(normalizedQuery)).slice(0, 30) }]
    : libraries.find((library) => library.code === libraryCode)?.categories ?? [];
  const resultCount = categories.reduce((total, category) => total + category.services.length, 0);
  const customParameters = new URLSearchParams();
  if (query.trim()) customParameters.set("q", query.trim().slice(0, 120));
  if (libraryCode) customParameters.set("library", libraryCode);
  const customHref = `/${locale}/besoin${customParameters.size ? `?${customParameters.toString()}` : ""}`;

  return <div className="min-w-0 max-w-full" dir={locale === "ar" ? "rtl" : "ltr"}>
    <label htmlFor="services-refine" className="mt-7 block text-sm font-semibold text-slate-700">{copy.domains}</label>
    <div className="relative mt-2"><Search aria-hidden="true" className="pointer-events-none absolute start-3 top-3.5 size-4 text-slate-500"/><input id="services-refine" type="search" value={query} onChange={(event) => setQuery(event.target.value.slice(0, 120))} placeholder={copy.searchHint} maxLength={120} className="min-h-11 w-full rounded-xl border border-slate-300 bg-white ps-10 pe-3"/></div>

    <fieldset className="mt-6 min-w-0 max-w-full"><legend className="text-sm font-semibold text-slate-700">{copy.domains}</legend><div className="mt-3 flex max-w-full gap-2 overflow-x-auto pb-2">{libraries.map((library) => <button key={library.code} type="button" aria-pressed={library.code === libraryCode} onClick={() => { setLibraryCode(library.code); setQuery(""); }} className="min-h-11 shrink-0 rounded-full border border-slate-300 bg-white px-4 text-sm font-semibold text-slate-700 aria-pressed:border-blue-700 aria-pressed:bg-blue-700 aria-pressed:text-white">{library.name}</button>)}</div></fieldset>

    <div className="mt-6 flex flex-wrap items-center justify-between gap-3"><h2 className="text-xl font-semibold text-[#0b1739]">{copy.results}</h2><p role="status" className="text-sm text-slate-600">{copy.resultCount(resultCount)}</p></div>
    {resultCount ? <div className="mt-4 space-y-6">{categories.map((category) => <section key={category.code} aria-labelledby={`services-category-${category.code}`}><h3 id={`services-category-${category.code}`} className="text-sm font-semibold text-slate-700" lang={category.code === "SEARCH" ? locale : "fr"}>{category.name}</h3><ul className="mt-2 grid gap-3 sm:grid-cols-2">{category.services.map((service) => {
      const parameters = new URLSearchParams({ serviceCode: service.code, service: service.name, library: service.libraryCode });
      return <li key={service.code} className="rounded-xl border border-slate-200 bg-white p-4"><h4 className="font-semibold text-slate-900" lang="fr">{service.name}</h4><p className="mt-2 line-clamp-2 text-sm leading-6 text-slate-600" lang="fr">{service.description}</p><Link href={`/${locale}/besoin?${parameters.toString()}`} className="mt-3 inline-flex min-h-11 items-center gap-2 rounded-lg font-semibold text-blue-700 hover:text-blue-900">{copy.serviceAction}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180"/></Link></li>;
    })}</ul></section>)}</div> : <p className="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-950">{copy.noResult}</p>}
    <div className="mt-7 flex justify-end"><Link href={customHref} className="inline-flex min-h-11 items-center gap-2 rounded-xl bg-blue-700 px-5 font-semibold text-white hover:bg-blue-800">{query.trim() ? copy.continue : copy.custom}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180"/></Link></div>
  </div>;
}
