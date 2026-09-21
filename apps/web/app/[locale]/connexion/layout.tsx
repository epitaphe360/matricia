import type { Metadata } from "next";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { localizedPublicMetadata } from "@/modules/shared/lib/seo/metadata";
import { PublicFooter } from "@/modules/public/ui/site/public-footer";
import { PublicNavigation } from "@/modules/public/ui/site/public-navigation";
import "../(public)/experience.css";

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  return { ...localizedPublicMetadata(locale, "/connexion"), robots: { index: false, follow: false, noarchive: true } };
}

export default async function PublicLoginLayout({ children, params }: Readonly<{ children: React.ReactNode; params: Promise<{ locale: string }> }>) {
  const { locale } = await params;
  if (!isLocale(locale)) return children;
  return (
    <div dir={locale === "ar" ? "rtl" : "ltr"} className="public-root flex min-h-dvh flex-col text-[#1a2340]">
      <PublicNavigation locale={locale} />
      <div className="flex-1">{children}</div>
      <PublicFooter locale={locale} />
    </div>
  );
}
