import type { Metadata } from "next";
import { isLocale } from "@/lib/i18n/locale";
import { localizedPublicMetadata } from "@/lib/seo/metadata";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  return { ...localizedPublicMetadata(locale, "/connexion"), robots: { index: false, follow: false, noarchive: true } };
}

export default function PublicLoginLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return children;
}
