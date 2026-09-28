"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  BarChart3,
  Briefcase,
  Building2,
  Check,
  Cpu,
  HardHat,
  Megaphone,
  Scale,
  Search,
  ShieldCheck,
  Truck,
  Users,
  Wallet,
  X,
} from "lucide-react";
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

const libraryIcons: Record<string, typeof Cpu> = {
  IT: Cpu,
  COM: Megaphone,
  ACC: Wallet,
  LEGAL: Scale,
  HR: Users,
  INS: ShieldCheck,
  LOG: Truck,
  BTP: HardHat,
  QHSE: Building2,
  SALES: Briefcase,
};

export function ProviderTaxonomySelector({
  locale,
  libraries,
  activityLabel,
  activityExample,
}: {
  locale: Locale;
  libraries: Library[];
  activityLabel: string;
  activityExample: string;
}) {
  const copy = getPublicProviderIntentMessages(locale);
  const [libraryCode, setLibraryCode] = useState(libraries[0]?.code ?? "");
  const [domainQuery, setDomainQuery] = useState("");
  const [query, setQuery] = useState("");
  const [serviceCodes, setServiceCodes] = useState<string[]>([]);
  const [otherEnabled, setOtherEnabled] = useState(false);
  const [otherService, setOtherService] = useState("");
  const [activity, setActivity] = useState("");
  const [hydrated, setHydrated] = useState(false);
  const [storageAvailable, setStorageAvailable] = useState(true);

  const allServices = useMemo(() => libraries.flatMap((library) => library.categories.flatMap((category) => category.services)), [libraries]);
  const serviceByCode = useMemo(() => new Map(allServices.map((service) => [service.code, service])), [allServices]);
  const normalizedDomain = domainQuery.trim().toLocaleLowerCase(locale === "ar" ? "ar" : "fr");
  const visibleLibraries = normalizedDomain
    ? libraries.filter((library) => library.name.toLocaleLowerCase(locale === "ar" ? "ar" : "fr").includes(normalizedDomain))
    : libraries;
  const normalizedQuery = query.trim().toLocaleLowerCase(locale === "ar" ? "ar" : "fr");
  const visibleCategories = (normalizedQuery
    ? [{ code: "SEARCH", name: copy.search, services: allServices.filter((service) => `${service.name} ${service.description}`.toLocaleLowerCase("fr").includes(normalizedQuery)).slice(0, 24) }]
    : libraries.find((library) => library.code === libraryCode)?.categories ?? []);
  const visibleServices = visibleCategories.flatMap((category) => category.services);
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
        const legacy = window.localStorage.getItem(PROVIDER_INTENT_LEGACY_KEY)?.trim() ?? "";
        if (legacy && !legacy.startsWith("Services sélectionnés") && !legacy.startsWith("الخدمات المختارة")) {
          setActivity(legacy.slice(0, 300));
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
        const legacy = activity.trim().length >= 3
          ? activity.trim().slice(0, 2_000)
          : summarizeProviderIntent(draft, locale);
        window.localStorage.setItem(PROVIDER_INTENT_LEGACY_KEY, legacy);
        setStorageAvailable(true);
      } catch {
        setStorageAvailable(false);
      }
    }, 250);
    return () => window.clearTimeout(timer);
  }, [activity, hydrated, locale, otherEnabled, otherService, serviceCodes]);

  function toggleService(code: string) {
    setServiceCodes((current) => current.includes(code)
      ? current.filter((item) => item !== code)
      : current.length < MAX_PROVIDER_SERVICES ? [...current, code] : current);
  }

  return (
    <section aria-labelledby="provider-taxonomy-title" className="provider-guided min-w-0 max-w-full">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id="provider-taxonomy-title" className="text-xl font-semibold text-[var(--mat-navy)]">{copy.title}</h2>
          <p className="mt-1 text-sm text-slate-600">{serviceCodes.length}/{MAX_PROVIDER_SERVICES}</p>
        </div>
        {hydrated && storageAvailable ? <p role="status" className="text-sm text-emerald-700" suppressHydrationWarning>{copy.saved}</p> : null}
      </div>

      <div className="journey-provider-board">
        <div className="provider-step" data-tone="violet">
          <p className="provider-step-label"><span aria-hidden="true">1</span> {activityLabel}</p>
          <label className="grid gap-2">
            <span className="sr-only">{activityLabel}</span>
            <textarea
              value={activity}
              onChange={(event) => setActivity(event.target.value.slice(0, 300))}
              maxLength={300}
              rows={7}
              className="min-h-40 w-full rounded-xl border border-slate-300 bg-white p-3"
              placeholder={activityExample}
            />
            <span className="text-xs text-slate-500 text-end">{activity.length}/300</span>
          </label>
        </div>

        <fieldset className="provider-step min-w-0" data-tone="mint">
          <legend className="provider-step-label"><span aria-hidden="true">2</span> {copy.chooseDomain}</legend>
          <label htmlFor="provider-domain-search" className="sr-only">{copy.chooseDomain}</label>
          <div className="relative mt-2">
            <Search aria-hidden="true" className="pointer-events-none absolute start-3 top-3.5 size-4 text-slate-500" />
            <input
              id="provider-domain-search"
              value={domainQuery}
              onChange={(event) => setDomainQuery(event.target.value.slice(0, 80))}
              className="min-h-11 w-full rounded-xl border border-slate-300 bg-white ps-10 pe-3"
              type="search"
              maxLength={80}
              placeholder={locale === "ar" ? "ابحث عن مجال…" : "Rechercher un domaine…"}
            />
          </div>
          <div className="provider-domain-list mt-3">
            {visibleLibraries.map((library) => {
              const Icon = libraryIcons[library.code] ?? BarChart3;
              const pressed = libraryCode === library.code;
              return (
                <button
                  key={library.code}
                  type="button"
                  onClick={() => { setLibraryCode(library.code); setQuery(""); }}
                  aria-pressed={pressed}
                  className="provider-domain-card"
                >
                  <span className="provider-domain-icon" aria-hidden="true"><Icon size={18} /></span>
                  <span className="min-w-0 truncate font-semibold">{library.name}</span>
                </button>
              );
            })}
          </div>
          {visibleLibraries.length === 0 ? <p className="mt-3 text-sm text-slate-600">{copy.noResult}</p> : null}
        </fieldset>

        <div className="provider-step min-w-0" data-tone="coral">
          <p className="provider-step-label"><span aria-hidden="true">3</span> {copy.title}</p>
          <label htmlFor="provider-service-search" className="sr-only">{copy.search}</label>
          <div className="relative mt-2">
            <Search aria-hidden="true" className="pointer-events-none absolute start-3 top-3.5 size-4 text-slate-500" />
            <input
              id="provider-service-search"
              value={query}
              onChange={(event) => setQuery(event.target.value.slice(0, 120))}
              className="min-h-11 w-full rounded-xl border border-slate-300 bg-white ps-10 pe-3"
              type="search"
              maxLength={120}
              placeholder={copy.search}
            />
          </div>

          {visibleServices.length === 0 ? <p className="mt-3 rounded-xl bg-white p-4 text-sm text-slate-600">{copy.noResult}</p> : normalizedQuery ? (
            <div className="provider-service-chips mt-3" role="group" aria-label={copy.title} aria-live="polite">
              {visibleServices.map((service) => {
                const checked = serviceCodes.includes(service.code);
                const disabled = !checked && serviceCodes.length >= MAX_PROVIDER_SERVICES;
                return (
                  <button
                    key={service.code}
                    type="button"
                    title={service.description}
                    aria-pressed={checked}
                    disabled={disabled}
                    onClick={() => toggleService(service.code)}
                    className={`provider-service-chip${checked ? " is-selected" : ""}`}
                  >
                    <span lang="fr">{service.name}</span>
                  </button>
                );
              })}
            </div>
          ) : (
            visibleCategories.map((category, index) => (
              <details key={category.code} className="provider-category" open={index === 0}>
                <summary>
                  {category.name}
                  <span dir="ltr">{category.services.length}</span>
                </summary>
                <div className="provider-service-chips" role="group" aria-label={category.name}>
                  {category.services.map((service) => {
                    const checked = serviceCodes.includes(service.code);
                    const disabled = !checked && serviceCodes.length >= MAX_PROVIDER_SERVICES;
                    return (
                      <button
                        key={service.code}
                        type="button"
                        title={service.description}
                        aria-pressed={checked}
                        disabled={disabled}
                        onClick={() => toggleService(service.code)}
                        className={`provider-service-chip${checked ? " is-selected" : ""}`}
                      >
                        <span lang="fr">{service.name}</span>
                      </button>
                    );
                  })}
                </div>
              </details>
            ))
          )}
          {serviceCodes.length >= MAX_PROVIDER_SERVICES ? <p role="status" className="mt-3 text-sm text-amber-800">{copy.limit}</p> : null}

          {serviceCodes.length > 0 ? (
            <div className="mt-4 min-w-0">
              <h3 className="text-sm font-semibold text-slate-700">{copy.selected}</h3>
              <ul className="mt-2 flex min-w-0 max-w-full flex-wrap gap-2">
                {serviceCodes.map((code) => (
                  <li className="min-w-0 max-w-full" key={code}>
                    <button type="button" onClick={() => toggleService(code)} className="inline-flex min-h-11 max-w-full items-center gap-2 rounded-full bg-[var(--mat-violet-soft)] px-3 text-sm font-medium text-[var(--mat-navy-soft)]">
                      <Check aria-hidden="true" className="size-4 shrink-0" />
                      <span className="min-w-0 break-words" lang="fr">{serviceByCode.get(code)?.name ?? code}</span>
                      <X aria-hidden="true" className="size-4 shrink-0" />
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          <button
            type="button"
            className="provider-other-toggle mt-4"
            aria-pressed={otherEnabled}
            onClick={() => setOtherEnabled((value) => !value)}
          >
            + {copy.otherToggle}
          </button>
          {otherEnabled ? (
            <div className="mt-2">
              <label htmlFor="provider-other-service" className="text-sm font-semibold text-slate-700">{copy.otherLabel}</label>
              <textarea
                id="provider-other-service"
                value={otherService}
                onChange={(event) => setOtherService(event.target.value.slice(0, 500))}
                rows={3}
                maxLength={500}
                className="mt-2 w-full rounded-xl border border-slate-300 bg-white p-3"
              />
            </div>
          ) : null}

          {!storageAvailable ? <p role="alert" className="mt-3 text-sm text-amber-800">{copy.storageUnavailable}</p> : null}
          {!hasIntent ? <p className="mt-4 text-sm text-slate-600">{copy.empty}</p> : null}

          <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <Link className="inline-flex min-h-11 items-center justify-center rounded-xl border border-slate-300 bg-white px-5 font-semibold text-slate-800" href={existingAccount}>{copy.existing}</Link>
            <Link
              aria-disabled={!hasIntent}
              tabIndex={hasIntent ? undefined : -1}
              className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-[var(--jp-blue)] px-5 font-semibold text-white aria-disabled:pointer-events-none aria-disabled:opacity-50"
              href={registration}
            >
              {copy.continue}
              <ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180" />
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
