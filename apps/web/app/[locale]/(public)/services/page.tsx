import { redirect } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
export default async function ServicesTransition({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ q?: string | string[]; library?: string | string[] }> }) {
  const { locale } = await params; const query = await searchParams;
  if (!isLocale(locale)) redirect("/fr");
  const knownNeed = typeof query.q === "string" ? query.q.slice(0, 500) : typeof query.library === "string" ? query.library.slice(0, 120) : "";
  redirect("/" + locale + (knownNeed ? "/besoin?q=" + encodeURIComponent(knownNeed) : "/diagnostic"));
}
