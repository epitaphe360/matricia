"use client";
import { usePathname } from "next/navigation";
export default function RecurringError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const arabic = usePathname().split("/")[1] === "ar";
  return <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6" dir={arabic ? "rtl" : "ltr"}><section role="alert" className="mx-auto max-w-3xl rounded-2xl border bg-card p-6 shadow-sm"><h1 className="text-2xl font-semibold">{arabic ? "تعذر تحميل الطلبات المتكررة" : "Impossible de charger les demandes récurrentes"}</h1><p className="mt-3 text-muted-foreground">{arabic ? "أعد المحاولة. لم يتم تعديل أي خطة." : "Réessayez. Aucun plan n’a été modifié."}</p><button type="button" onClick={reset} className="mt-5 min-h-11 rounded-md bg-primary px-4 font-medium text-primary-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">{arabic ? "إعادة المحاولة" : "Réessayer"}</button></section></main>;
}
