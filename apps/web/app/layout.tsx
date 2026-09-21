import type { Metadata } from "next";
import { headers } from "next/headers";
import { directionFor, normalizeLocale } from "@/modules/shared/lib/i18n/locale";
import { getPublicSiteUrl, publicStructuredData } from "@/modules/shared/lib/seo/metadata";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: getPublicSiteUrl(),
  title: { default: "Matricia", template: "%s | Matricia" },
  description: "Plateforme numérique Matricia pour les services professionnels au Maroc.",
  applicationName: "Matricia",
  robots: { index: false, follow: false, noarchive: true },
  openGraph: { type: "website", siteName: "Matricia", title: "Matricia", description: "Plateforme numérique de services professionnels au Maroc.", images: [{ url: "/social-card.svg", width: 1200, height: 630, alt: "Matricia" }] },
  twitter: { card: "summary_large_image", title: "Matricia", description: "Plateforme numérique de services professionnels au Maroc.", images: ["/social-card.svg"] },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const requestHeaders = await headers();
  const locale = normalizeLocale(requestHeaders.get("x-matricia-locale"));
  const structuredData = publicStructuredData(locale);
  return (
    <html lang={locale} dir={directionFor(locale)}>
      <body className="antialiased">
        {children}
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: structuredData }} />
      </body>
    </html>
  );
}
