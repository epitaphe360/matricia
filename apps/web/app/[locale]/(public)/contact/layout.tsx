import type { Metadata } from "next";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";
import { getContactMessages } from "./messages";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const copy = getContactMessages(locale);
  return localizedRouteMetadata(locale, "/contact", copy.title, copy.description);
}

export default function PublicContactLayout({ children }: Readonly<{ children: React.ReactNode }>) { return children; }
