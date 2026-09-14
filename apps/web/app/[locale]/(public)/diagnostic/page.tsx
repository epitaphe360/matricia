import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { isLocale } from "@/lib/i18n/locale";
import { localizedRouteMetadata } from "@/lib/seo/metadata";
import { PrediagnosticFlow } from "@/components/public-journey/prediagnostic-flow";
export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params; if (!isLocale(locale)) return {};
  return localizedRouteMetadata(locale, "/diagnostic", locale === "fr" ? "Prédiagnostic entreprise | Matricia" : "تقييم أولي للشركة | ماتريسيا", locale === "fr" ? "Comprenez vos priorités avant d’agir." : "افهموا أولوياتكم قبل التحرك.");
}
export default async function DiagnosticPage({ params }: { params: Promise<{ locale: string }> }) { const { locale } = await params; if (!isLocale(locale)) notFound(); return <PrediagnosticFlow locale={locale} />; }
