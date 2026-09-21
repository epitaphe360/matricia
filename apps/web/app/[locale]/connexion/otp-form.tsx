"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseBrowserClient } from "@/modules/shared/lib/supabase/client";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getDictionary } from "@/modules/shared/lib/i18n/dictionaries";
import { normalizeEmail, normalizeOtp } from "@/modules/shared/lib/auth/otp";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Label } from "@/modules/shared/ui/label";
import { requestOtp } from "./actions";
import { getLoginMessages } from "./messages";

export function OtpForm({ locale, nextPath, intent = "login" }: { locale: Locale; nextPath?: string; intent?: "login" | "registration" }) {
  const messages = getDictionary(locale).auth;
  const local = getLoginMessages(locale);
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [method, setMethod] = useState<"otp" | "password">("otp");
  const [token, setToken] = useState("");
  const [step, setStep] = useState<"email" | "code">("email");
  const [status, setStatus] = useState<"idle" | "pending" | "error">("idle");
  const [message, setMessage] = useState("");

  async function requestCode(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedEmail = normalizeEmail(email);
    if (!normalizedEmail) { setMessage(messages.invalidEmail); return; }
    setStatus("pending"); setMessage("");
    let result;
    try {
      result = await requestOtp(normalizedEmail, locale, nextPath, intent);
    } catch {
      setStatus("error"); setMessage(messages.genericError); return;
    }
    if (!result.accepted) { setStatus("error"); setMessage(messages.invalidEmail); return; }
    setEmail(normalizedEmail); setStep("code"); setStatus("idle"); setMessage(messages.sent);
  }

  async function verifyCode(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedToken = normalizeOtp(token);
    if (!normalizedToken) { setMessage(messages.invalidCode); return; }
    setStatus("pending"); setMessage("");
    const { error } = await getSupabaseBrowserClient().auth.verifyOtp({ email, token: normalizedToken, type: "email" });
    if (error) { setStatus("error"); setMessage(messages.genericError); return; }
    router.replace(nextPath ?? "/" + locale + "/tableau-de-bord");
    router.refresh();
  }

  async function resendCode() {
    setStatus("pending"); setMessage("");
    try {
      const result = await requestOtp(email, locale, nextPath, intent);
      if (!result.accepted) { setStatus("error"); setMessage(messages.genericError); return; }
      setStatus("idle"); setMessage(local.resent);
    } catch {
      setStatus("error"); setMessage(messages.genericError);
    }
  }

  async function signInWithPassword(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedEmail = normalizeEmail(email);
    if (!normalizedEmail) { setMessage(messages.invalidEmail); return; }
    if (password.length < 12 || password.length > 72) { setMessage(messages.invalidPassword); return; }
    setStatus("pending"); setMessage("");
    const { error } = await getSupabaseBrowserClient().auth.signInWithPassword({
      email: normalizedEmail,
      password,
    });
    if (error) { setStatus("error"); setMessage(messages.genericError); return; }
    router.replace(nextPath ?? "/" + locale + "/tableau-de-bord");
    router.refresh();
  }

  function selectMethod(nextMethod: "otp" | "password") {
    setMethod(nextMethod);
    setStep("email");
    setToken("");
    setPassword("");
    setStatus("idle");
    setMessage("");
  }

  if (method === "password") return (
    <div className="space-y-6">
      <div className="grid grid-cols-2 gap-1 rounded-xl bg-slate-100 p-1" role="group" aria-label={messages.methodLabel}>
        <Button className="min-h-11 rounded-lg border-transparent bg-transparent shadow-none" type="button" variant="outline" onClick={() => selectMethod("otp")}>{messages.otpMethod}</Button>
        <Button className="min-h-11 rounded-lg bg-[#0b1739]" type="button" aria-pressed="true">{messages.passwordMethod}</Button>
      </div>
      <form onSubmit={signInWithPassword} className="space-y-5" noValidate aria-busy={status === "pending"}>
        <div className="space-y-2"><Label className="text-sm font-semibold text-slate-700" htmlFor="email">{messages.emailLabel}</Label><Input className="min-h-12 rounded-xl border-slate-400 bg-white px-4 text-base" id="email" name="email" type="email" autoComplete="username" inputMode="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder={messages.emailPlaceholder} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
        <div className="space-y-2"><Label className="text-sm font-semibold text-slate-700" htmlFor="password">{messages.passwordLabel}</Label><Input className="min-h-12 rounded-xl border-slate-400 bg-white px-4 text-base" id="password" name="password" type="password" autoComplete="current-password" minLength={12} maxLength={72} value={password} onChange={(event) => setPassword(event.target.value)} aria-describedby="password-hint auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /><p id="password-hint" className="text-sm text-slate-500">{messages.passwordHint}</p></div>
        <Button className="min-h-12 w-full rounded-xl bg-blue-700 text-base hover:bg-blue-800" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.signInWithPassword}</Button>
        <p id="auth-status" role={status === "error" ? "alert" : "status"} aria-live="polite" className={status === "error" ? "text-sm font-medium text-destructive" : "text-sm text-slate-600"}>{message}</p>
      </form>
    </div>
  );

  return step === "email" ? (
    <div className="space-y-6">
      {intent === "login" ? <div className="grid grid-cols-2 gap-1 rounded-xl bg-slate-100 p-1" role="group" aria-label={messages.methodLabel}>
        <Button className="min-h-11 rounded-lg bg-[#0b1739]" type="button" aria-pressed="true">{messages.otpMethod}</Button>
        <Button className="min-h-11 rounded-lg border-transparent bg-transparent shadow-none" type="button" variant="outline" onClick={() => selectMethod("password")}>{messages.passwordMethod}</Button>
      </div> : null}
      <form onSubmit={requestCode} className="space-y-5" noValidate aria-busy={status === "pending"}>
      <div className="space-y-2"><Label className="text-sm font-semibold text-slate-700" htmlFor="email">{messages.emailLabel}</Label><Input className="min-h-12 rounded-xl border-slate-400 bg-white px-4 text-base" id="email" name="email" type="email" autoComplete="email" inputMode="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder={messages.emailPlaceholder} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
      <Button className="min-h-12 w-full rounded-xl bg-blue-700 text-base hover:bg-blue-800" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.requestCode}</Button>
      <p id="auth-status" role={status === "error" ? "alert" : "status"} aria-live="polite" className={status === "error" ? "text-sm font-medium text-destructive" : "text-sm text-slate-600"}>{message}</p>
      </form>
    </div>
  ) : (
    <div className="grid gap-6 lg:grid-cols-[minmax(0,1.1fr)_minmax(220px,.9fr)]">
    <form onSubmit={verifyCode} className="space-y-5" noValidate aria-busy={status === "pending"}>
      <div className="space-y-2">
        <Label className="text-sm font-semibold text-slate-700" htmlFor="otp">{messages.codeLabel}</Label>
        <p className="text-sm text-slate-600">{locale === "ar" ? "تم إرسال رمز من 6 أرقام إلى عنوانكم." : "Un code à 6 chiffres a été envoyé à votre adresse."}</p>
        <input id="otp" name="otp" value={token} onChange={(event) => setToken(event.target.value.replace(/\D/g, "").slice(0, 6))} autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} className="sr-only" />
        <div className="public-otp-boxes" role="group" aria-label={messages.codeLabel}>
          {Array.from({ length: 6 }, (_, index) => (
            <input
              key={index}
              type="text"
              inputMode="numeric"
              maxLength={1}
              value={token[index] ?? ""}
              className={status === "error" ? "is-invalid" : undefined}
              aria-label={`${index + 1} / 6`}
              onChange={(event) => {
                const digit = event.target.value.replace(/\D/g, "").slice(-1);
                const next = Array.from({ length: 6 }, (_, position) => position === index ? digit : token[position] ?? "").join("").replace(/\s/g, "");
                setToken(next.slice(0, 6));
                const sibling = event.currentTarget.nextElementSibling;
                if (digit && sibling instanceof HTMLInputElement) sibling.focus();
              }}
              onKeyDown={(event) => {
                if (event.key === "Backspace" && !token[index]) {
                  const previous = event.currentTarget.previousElementSibling;
                  if (previous instanceof HTMLInputElement) previous.focus();
                }
              }}
              onPaste={(event) => {
                const pasted = event.clipboardData.getData("text").replace(/\D/g, "").slice(0, 6);
                if (!pasted) return;
                event.preventDefault();
                setToken(pasted);
              }}
            />
          ))}
        </div>
      </div>
      <Button className="min-h-12 w-full rounded-xl bg-blue-700 text-base hover:bg-blue-800" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : locale === "ar" ? "التحقق والمتابعة" : "Vérifier et continuer"}</Button>
      <div className="grid gap-2 sm:grid-cols-2"><button type="button" className="min-h-11 rounded-lg px-3 text-sm font-semibold text-blue-700 hover:bg-blue-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" disabled={status === "pending"} onClick={resendCode}>{local.resend}</button><button type="button" className="min-h-11 rounded-lg px-3 text-sm font-semibold text-slate-600 hover:bg-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" onClick={() => { setStep("email"); setToken(""); setMessage(""); }}>{messages.changeEmail}</button></div>
      <p id="auth-status" role={status === "error" ? "alert" : "status"} aria-live="polite" className={status === "error" ? "text-sm font-medium text-destructive" : "text-sm text-slate-600"}>{message}</p>
    </form>
    <aside className="grid gap-4">
      {nextPath ? (
        <article className="rounded-2xl border border-[#eadfce] bg-[#fbf7ff] p-4">
          <h2 className="text-base font-semibold">{locale === "ar" ? "مساركم محفوظ" : "Votre parcours est conservé"}</h2>
          <p className="mt-2 text-sm leading-6 text-slate-600">{locale === "ar" ? "ستستأنفون من نفس النقطة بعد التحقق." : "Vous reprendrez exactement où vous en étiez arrêté après vérification."}</p>
        </article>
      ) : null}
      <article className="public-illustrative" aria-label={locale === "ar" ? "مثال توضيحي" : "Exemple illustratif"}>
        <small>{locale === "ar" ? "حالات توضيحية" : "États illustratifs"} · {locale === "ar" ? "مثال توضيحي" : "Exemple illustratif"}</small>
        <p className="mt-2 text-sm">{locale === "ar" ? "التحقق جارٍ… انتظروا لحظات." : "Vérification en cours… Veuillez patienter quelques instants."}</p>
        <p className="mt-2 text-sm text-red-700">{locale === "ar" ? "رمز غير صالح. حاولوا مجدداً." : "Ce code n’est pas valide. Veuillez réessayer."}</p>
        <p className="mt-2 text-sm text-red-700">{locale === "ar" ? "انتهت صلاحية الرمز. اطلبوا رمزاً جديداً." : "Ce code a expiré. Veuillez demander un nouveau code."}</p>
      </article>
    </aside>
    </div>
  );
}
