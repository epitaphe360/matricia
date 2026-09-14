import { ArrowLeft, Check, LockKeyhole } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { isLocale } from "@/lib/i18n/locale";
import { getLoginMessages } from "./messages";
import { OtpForm } from "./otp-form";

export default async function LoginPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ next?: string | string[] }> }) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const messages = getDictionary(locale).auth;
  const chrome = getLoginMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";
  const nextPath = typeof query.next === "string" && query.next.startsWith("/" + locale + "/") && !query.next.startsWith("//") && !query.next.includes("\\") ? query.next : undefined;
  const translatedNextPath = nextPath ? `/${alternate}/${nextPath.split("/").slice(2).join("/")}` : undefined;
  const languageHref = `/${alternate}/connexion${translatedNextPath ? `?next=${encodeURIComponent(translatedNextPath)}` : ""}`;

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
          <h1 id="login-title" className="mt-6 text-3xl font-semibold leading-tight tracking-[-0.03em] sm:text-4xl rtl:tracking-normal">{messages.title}</h1>
          <p className="mt-4 max-w-xl leading-7 text-slate-600">{messages.description}</p>
          {nextPath ? <p className="mt-5 rounded-xl border border-blue-100 bg-blue-50 px-4 py-3 text-sm leading-6 text-blue-950">{chrome.continuity}</p> : null}
          <div className="mt-8"><OtpForm locale={locale} nextPath={nextPath} /></div>
          <p className="mt-7 flex items-start gap-2 text-sm leading-6 text-slate-500"><LockKeyhole aria-hidden="true" className="mt-0.5 size-4 shrink-0" /><span>{chrome.security}</span></p>
          <Link href={`/${locale}`} className="mt-5 inline-flex min-h-11 items-center gap-2 rounded-lg text-sm font-semibold text-slate-600 hover:text-blue-700"><ArrowLeft aria-hidden="true" className="size-4 rtl:rotate-180" />{chrome.back}</Link>
        </section>
      </div>
    </div>
  </main>;
}
