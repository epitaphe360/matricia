import { ArrowLeft, Check, LockKeyhole } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { isLocale } from "@/lib/i18n/locale";
import { getLoginMessages } from "./messages";
import { OtpForm } from "./otp-form";

export default async function LoginPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ next?: string | string[]; mode?: string; role?: string }> }) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const messages = getDictionary(locale).auth;
  const chrome = getLoginMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  const registration = query.mode === "inscription";
  const registrationRole = query.role === "fournisseur" ? "fournisseur" : "client";
  const nextPath = typeof query.next === "string" && query.next.startsWith("/" + locale + "/") && !query.next.startsWith("//") && !query.next.includes("\\") ? query.next : undefined;
  const defaultRegistrationPath = `/${locale}/organisation${registrationRole === "fournisseur" ? "?role=fournisseur" : ""}`;
  const effectiveNextPath = registration ? nextPath ?? defaultRegistrationPath : nextPath;
  const translatedNextPath = effectiveNextPath ? `/${alternate}/${effectiveNextPath.split("/").slice(2).join("/")}` : undefined;
  const languageQuery = registration ? `?mode=inscription&role=${registrationRole}${translatedNextPath ? `&next=${encodeURIComponent(translatedNextPath)}` : ""}` : translatedNextPath ? `?next=${encodeURIComponent(translatedNextPath)}` : "";
  const languageHref = `/${alternate}/connexion${languageQuery}`;

  return <main dir={locale === "ar" ? "rtl" : "ltr"} className="relative min-h-dvh overflow-hidden bg-[#f7f9fc] px-4 py-6 text-[#14213d] sm:px-6 lg:grid lg:place-items-center lg:px-8 lg:py-10">
    <div aria-hidden="true" className="absolute -end-32 -top-40 size-[32rem] rounded-full bg-blue-100/70 blur-3xl" />
    <div className="relative mx-auto w-full max-w-6xl">
      <nav aria-label={chrome.back} className="mb-6 flex items-center justify-between sm:mb-8">
        <Link href={`/${locale}`} className="inline-flex min-h-11 items-center gap-2 rounded-lg px-2 text-lg font-semibold text-[#0b1739] focus-visible:outline focus-visible:outline-3 focus-visible:outline-blue-700"><span>{chrome.brand}</span></Link>
        <Link href={languageHref} hrefLang={alternate} className="inline-flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold text-blue-700 hover:bg-blue-50">{messages.language}</Link>
      </nav>

      <div className="grid overflow-hidden rounded-3xl border border-slate-200 bg-white shadow-[0_24px_64px_rgba(7,30,53,.12)] lg:grid-cols-[.9fr_1.1fr]">
        <aside className="order-2 bg-[#0b1739] p-7 text-white sm:p-10 lg:order-1 lg:p-12" aria-labelledby="login-context-title">
          <p className="text-sm font-semibold uppercase tracking-[0.14em] text-blue-300 rtl:tracking-normal">{chrome.panelEyebrow}</p>
          <h2 id="login-context-title" className="mt-5 text-3xl font-semibold leading-tight tracking-[-0.025em] rtl:tracking-normal">{chrome.panelTitle}</h2>
          <p className="mt-5 leading-7 text-slate-300">{chrome.panelBody}</p>
          <ul className="mt-9 space-y-4">{chrome.trust.map((item) => <li key={item} className="flex items-start gap-3 text-sm leading-6 text-slate-200"><span className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-blue-700"><Check aria-hidden="true" className="size-3.5" /></span><span>{item}</span></li>)}</ul>
        </aside>

        <section className="order-1 p-6 sm:p-10 lg:order-2 lg:p-12" aria-labelledby="login-title">
          <div className="flex items-center gap-3"><span className="grid size-11 place-items-center rounded-2xl bg-blue-50 text-blue-700"><LockKeyhole aria-hidden="true" className="size-5" /></span><span className="text-sm font-semibold uppercase tracking-[0.14em] text-blue-700 rtl:tracking-normal">{messages.eyebrow}</span></div>
          <h1 id="login-title" className="mt-6 text-3xl font-semibold leading-tight tracking-[-0.03em] sm:text-4xl rtl:tracking-normal">{registration ? chrome.signupPageTitle : messages.title}</h1>
          <p className="mt-4 max-w-xl leading-7 text-slate-600">{registration ? chrome.signupPageDescription : messages.description}</p>
          {registration ? <div className="mt-6 grid grid-cols-2 gap-2 rounded-xl bg-slate-100 p-1" aria-label={chrome.signupTitle}><Link aria-current={registrationRole === "client" ? "page" : undefined} href={`/${locale}/connexion?mode=inscription&role=client${nextPath ? `&next=${encodeURIComponent(nextPath)}` : ""}`} className="min-h-11 rounded-lg px-3 py-3 text-center text-sm font-semibold aria-[current=page]:bg-white aria-[current=page]:text-blue-700 aria-[current=page]:shadow-sm">{chrome.clientAccount}</Link><Link aria-current={registrationRole === "fournisseur" ? "page" : undefined} href={`/${locale}/connexion?mode=inscription&role=fournisseur${nextPath ? `&next=${encodeURIComponent(nextPath)}` : ""}`} className="min-h-11 rounded-lg px-3 py-3 text-center text-sm font-semibold aria-[current=page]:bg-white aria-[current=page]:text-blue-700 aria-[current=page]:shadow-sm">{chrome.providerAccount}</Link></div> : null}
          {!registration && nextPath ? <p className="mt-5 rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-sm leading-6 text-blue-950">{chrome.continuity}</p> : null}
          <div className="mt-8"><OtpForm locale={locale} nextPath={effectiveNextPath} intent={registration ? "registration" : "login"} /></div>
          <div className="mt-7 border-t border-slate-200 pt-6 text-center"><p className="text-sm text-slate-600">{registration ? chrome.loginTitle : chrome.signupTitle}</p>{registration ? <Link href={`/${locale}/connexion`} className="mt-2 inline-flex min-h-11 items-center font-semibold text-blue-700 underline-offset-4 hover:underline">{chrome.loginAction}</Link> : <div className="mt-3 flex flex-col justify-center gap-2 sm:flex-row"><Link href={`/${locale}/connexion?mode=inscription&role=client`} className="inline-flex min-h-11 items-center justify-center rounded-lg border border-blue-700 px-4 font-semibold text-blue-700 hover:bg-blue-50">{chrome.clientAccount}</Link><Link href={`/${locale}/connexion?mode=inscription&role=fournisseur`} className="inline-flex min-h-11 items-center justify-center rounded-lg border border-blue-700 px-4 font-semibold text-blue-700 hover:bg-blue-50">{chrome.providerAccount}</Link></div>}</div>
          <p className="mt-7 flex items-start gap-2 text-sm leading-6 text-slate-500"><LockKeyhole aria-hidden="true" className="mt-0.5 size-4 shrink-0" /><span>{chrome.security}</span></p>
          <Link href={`/${locale}`} className="mt-5 inline-flex min-h-11 items-center gap-2 rounded-lg text-sm font-semibold text-slate-600 hover:text-blue-700"><ArrowLeft aria-hidden="true" className="size-4 rtl:rotate-180" />{chrome.back}</Link>
        </section>
      </div>
    </div>
  </main>;
}
