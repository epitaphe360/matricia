import type { Metadata } from "next";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { getPublicMessages } from "../messages";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const copy = getPublicMessages(locale).services;
  return localizedRouteMetadata(locale, "/services", copy.title, copy.description);
}

export default function PublicServicesLayout({ children }: Readonly<{ children: React.ReactNode }>) { return children; }
