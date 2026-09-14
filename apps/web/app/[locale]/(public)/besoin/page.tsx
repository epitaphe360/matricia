import { notFound } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { NeedFlow } from "@/components/public-journey/need-flow";
export default async function NeedPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ q?: string | string[]; service?: string | string[] }> }) {
  const { locale } = await params; const query = await searchParams; if (!isLocale(locale)) notFound();
  const text = typeof query.q === "string" ? query.q.slice(0, 500) : typeof query.service === "string" ? query.service.slice(0, 120) : "";
  return <NeedFlow locale={locale} initialNeed={text} />;
}
