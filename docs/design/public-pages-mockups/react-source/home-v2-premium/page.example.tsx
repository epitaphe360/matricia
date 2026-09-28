import { notFound } from "next/navigation";
import { HomePremium } from "./HomePremium";
import type { HomeLocale } from "./home-premium.copy";

function isHomeLocale(value: string): value is HomeLocale {
  return value === "fr" || value === "ar";
}

export default async function PublicHomePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isHomeLocale(locale)) notFound();
  return <HomePremium locale={locale} />;
}
