"use client";
import { useParams } from "next/navigation";
import { useEffect } from "react";
import { Button } from "@/components/ui/button";
import { getQuestionnaireMessages } from "./messages";
export default function QuestionnaireError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) { const params = useParams<{ locale?: string }>(), locale = params.locale === "ar" ? "ar" : "fr", messages = getQuestionnaireMessages(locale); useEffect(() => { void error.digest; }, [error]); return <main className="grid min-h-dvh place-items-center bg-muted/40 p-4"><div role="alert" className="w-full max-w-lg rounded-2xl border bg-card p-6 text-center shadow-sm"><h1 className="text-xl font-semibold">{messages.loadError}</h1><Button onClick={reset} className="mt-5 min-h-11">{messages.retry}</Button></div></main>; }
