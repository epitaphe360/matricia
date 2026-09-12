import { ArrowRight } from "lucide-react";
import Link from "next/link";
import type { ReactNode } from "react";
import { buttonVariants } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import type { PublicMessages } from "../messages";

type Props = {
  children: ReactNode;
  locale: Locale;
  alternatePath: string;
  messages: PublicMessages["common"];
};

export function PublicShell({ children, locale, alternatePath, messages }: Props) {
  const alternate = locale === "fr" ? "ar" : "fr";
  return <>
    <a href="#contenu-principal" className="sr-only z-50 rounded-md bg-background px-4 py-3 font-semibold text-primary focus:not-sr-only focus:fixed focus:start-4 focus:top-4">{messages.skipToContent}</a>
    <div className="border-b bg-muted/30 px-4 sm:px-6"><div className="mx-auto flex max-w-7xl justify-end"><Link href={`/${alternate}${alternatePath}`} hrefLang={alternate} lang={alternate} aria-label={messages.languageLabel} className="inline-flex min-h-11 items-center rounded-md px-3 text-sm font-semibold text-primary hover:underline">{messages.language}</Link></div></div>
    {children}
  </>;
}

export function PublicCta({ locale, title, description, messages, secondaryHref, secondaryLabel }: { locale: Locale; title: string; description: string; messages: PublicMessages["common"]; secondaryHref?: string; secondaryLabel?: string }) {
  return <section className="bg-accent px-4 py-16 sm:px-6 lg:px-8"><div className="mx-auto flex max-w-5xl flex-col items-start justify-between gap-7 md:flex-row md:items-center"><div><h2 className="text-2xl font-semibold tracking-tight text-accent-foreground sm:text-3xl">{title}</h2><p className="mt-3 max-w-2xl leading-7 text-accent-foreground/80">{description}</p></div><div className="flex w-full flex-col gap-3 sm:w-auto sm:flex-row">{secondaryHref && secondaryLabel ? <Link href={secondaryHref} className={cn(buttonVariants({ variant: "outline", size: "lg" }), "min-h-11 bg-background")}>{secondaryLabel}</Link> : null}<Link href={`/${locale}/connexion`} className={cn(buttonVariants({ size: "lg" }), "min-h-11 gap-2")}>{messages.start}<ArrowRight aria-hidden="true" className="size-4 rtl:rotate-180" /></Link></div></div></section>;
}
