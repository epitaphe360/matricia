import type { Metadata } from "next";
import { headers } from "next/headers";
import { directionFor, normalizeLocale } from "@/lib/i18n/locale";
import "./globals.css";

export const metadata: Metadata = {
  title: "Matricia",
  description: "Matricia",
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
  return (
    <html lang={locale} dir={directionFor(locale)}>
      <body className="antialiased">{children}</body>
    </html>
  );
}
