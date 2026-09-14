import Link from "next/link";
import { notFound } from "next/navigation";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { isLocale } from "@/lib/i18n/locale";
import { OtpForm } from "./otp-form";

export default async function LoginPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ next?: string | string[] }> }) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const messages = getDictionary(locale).auth;
  const alternate = locale === "fr" ? "ar" : "fr";
  const nextPath = typeof query.next === "string" && query.next.startsWith("/" + locale + "/") && !query.next.startsWith("//") ? query.next : undefined;
  return <main className="grid min-h-dvh place-items-center bg-muted/40 px-4 py-10"><Card className="w-full max-w-md shadow-xl"><CardHeader className="space-y-3"><div className="flex items-center justify-between"><span className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</span><Link href={`/${alternate}/connexion`} hrefLang={alternate} className="rounded-md px-2 py-1 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link></div><CardTitle><h1 className="text-2xl">{messages.title}</h1></CardTitle><CardDescription>{messages.description}</CardDescription></CardHeader><CardContent><OtpForm locale={locale} nextPath={nextPath} /></CardContent></Card></main>;
}
