"use client";

import { usePathname } from "next/navigation";
import { getAssistanceMessages } from "./messages";

export default function AssistanceError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const locale = usePathname().split("/")[1] === "ar" ? "ar" : "fr";
  const messages = getAssistanceMessages(locale);
  return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6" dir={locale === "ar" ? "rtl" : "ltr"}><section role="alert" className="mx-auto max-w-3xl rounded-2xl border bg-card p-6 shadow-sm"><h1 className="text-2xl font-semibold">{messages.errorTitle}</h1><p className="mt-3 text-muted-foreground">{messages.error}</p><button type="button" onClick={reset} className="mt-5 min-h-11 rounded-md bg-primary px-4 font-medium text-primary-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{messages.retry}</button></section></main>;
}
