import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Matricia — Pilotage d’entreprise",
  description: "Plateforme de diagnostic, conformité et services professionnels Matricia.",
  other: {
    "codex-preview": "development",
  },
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body className="antialiased">{children}</body>
    </html>
  );
}
