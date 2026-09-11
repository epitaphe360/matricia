import { notFound } from "next/navigation";
import { directionFor, isLocale } from "@/lib/i18n/locale";

export default async function LocaleLayout({ children, params }: Readonly<{ children: React.ReactNode; params: Promise<{ locale: string }> }>) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <div dir={directionFor(locale)} className="min-h-dvh">{children}</div>;
}
