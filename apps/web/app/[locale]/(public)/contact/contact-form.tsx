"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { submitContactRequest, type ContactActionState } from "./actions";

const initial: ContactActionState = { status: "idle" };
const copy = {
  fr: { title: "Écrire à Matricia", category: "Objet de la demande", options: { CLIENT: "Projet d’entreprise", PROVIDER: "Parcours sous-traitant", FRANCHISE: "Candidature franchise", OTHER: "Autre question" }, email: "Adresse de réponse", message: "Votre message", help: "N’ajoutez aucune pièce ni donnée sensible ici. Utilisez votre espace sécurisé pour un dossier existant.", send: "Enregistrer ma demande", pending: "Enregistrement…", success: "Demande enregistrée. Référence", validation: "Vérifiez l’adresse et saisissez un message d’au moins 20 caractères.", rate: "Trop de demandes ont été enregistrées récemment. Réessayez plus tard.", unavailable: "La demande n’a pas pu être enregistrée. Aucun courriel n’a été annoncé comme envoyé." },
  ar: { title: "اكتبوا إلى ماتريسيا", category: "موضوع الطلب", options: { CLIENT: "مشروع شركة", PROVIDER: "مسار مقدم الخدمة", FRANCHISE: "طلب امتياز", OTHER: "سؤال آخر" }, email: "بريد الرد", message: "رسالتكم", help: "لا تضيفوا وثائق أو بيانات حساسة هنا. استخدموا فضاءكم الآمن لملف قائم.", send: "تسجيل طلبي", pending: "جارٍ التسجيل…", success: "تم تسجيل الطلب. المرجع", validation: "تحققوا من البريد واكتبوا رسالة من 20 حرفاً على الأقل.", rate: "تم تسجيل طلبات كثيرة مؤخراً. حاولوا لاحقاً.", unavailable: "تعذر تسجيل الطلب. لم يتم الإعلان عن إرسال أي بريد." },
} as const;

export function ContactForm({ locale }: { locale: Locale }) {
  const [state, action, pending] = useActionState(submitContactRequest, initial);
  const messages = copy[locale];
  return <section aria-labelledby="contact-form-title" className="mx-auto mt-12 max-w-3xl rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
    <h2 id="contact-form-title" className="text-2xl font-semibold text-[#0b1739]">{messages.title}</h2>
    <p className="mt-2 text-sm leading-6 text-slate-600">{messages.help}</p>
    <form action={action} className="mt-7 space-y-5">
      <input type="hidden" name="locale" value={locale} />
      <div className="absolute -start-[10000px]" aria-hidden="true"><label>Website<input name="website" tabIndex={-1} autoComplete="off" /></label></div>
      <label className="block font-medium">{messages.category}<select name="category" className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 bg-white px-3" defaultValue="CLIENT">{Object.entries(messages.options).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
      <label className="block font-medium">{messages.email}<input name="replyEmail" type="email" required autoComplete="email" className="mt-2 min-h-12 w-full rounded-xl border border-slate-300 px-3" /></label>
      <label className="block font-medium">{messages.message}<textarea name="message" required minLength={20} maxLength={4000} rows={7} className="mt-2 w-full rounded-xl border border-slate-300 p-3" /></label>
      <Button type="submit" disabled={pending} className="min-h-12 rounded-xl bg-blue-700 px-6 hover:bg-blue-800">{pending ? messages.pending : messages.send}</Button>
      {state.status === "success" ? <p role="status" className="rounded-xl bg-emerald-50 p-4 text-emerald-900">{messages.success} <strong dir="ltr">{state.reference}</strong>. {locale === "fr" ? "Cette confirmation porte sur l’enregistrement, pas sur la livraison d’un courriel." : "هذا التأكيد يخص التسجيل وليس تسليم بريد إلكتروني."}</p> : null}
      {state.status === "error" ? <p role="alert" className="rounded-xl bg-red-50 p-4 text-red-900">{state.reason === "VALIDATION" ? messages.validation : state.reason === "RATE_LIMITED" ? messages.rate : messages.unavailable}</p> : null}
    </form>
  </section>;
}
