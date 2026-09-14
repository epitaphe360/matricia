"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { getSupabaseBrowserClient } from "@/lib/supabase/client";
import type { Locale } from "@/lib/i18n/locale";
import { getDictionary } from "@/lib/i18n/dictionaries";
import { normalizeEmail, normalizeOtp } from "@/lib/auth/otp";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { requestOtp } from "./actions";
import { getLoginMessages } from "./messages";

export function OtpForm({ locale, nextPath }: { locale: Locale; nextPath?: string }) {
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
      result = await requestOtp(normalizedEmail, locale, nextPath);
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
      const result = await requestOtp(email, locale, nextPath);
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
      <div className="grid grid-cols-2 gap-1 rounded-xl bg-slate-100 p-1" role="group" aria-label={messages.methodLabel}>
        <Button className="min-h-11 rounded-lg bg-[#0b1739]" type="button" aria-pressed="true">{messages.otpMethod}</Button>
        <Button className="min-h-11 rounded-lg border-transparent bg-transparent shadow-none" type="button" variant="outline" onClick={() => selectMethod("password")}>{messages.passwordMethod}</Button>
      </div>
      <form onSubmit={requestCode} className="space-y-5" noValidate aria-busy={status === "pending"}>
      <div className="space-y-2"><Label className="text-sm font-semibold text-slate-700" htmlFor="email">{messages.emailLabel}</Label><Input className="min-h-12 rounded-xl border-slate-400 bg-white px-4 text-base" id="email" name="email" type="email" autoComplete="email" inputMode="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder={messages.emailPlaceholder} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
      <Button className="min-h-12 w-full rounded-xl bg-blue-700 text-base hover:bg-blue-800" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.requestCode}</Button>
      <p id="auth-status" role={status === "error" ? "alert" : "status"} aria-live="polite" className={status === "error" ? "text-sm font-medium text-destructive" : "text-sm text-slate-600"}>{message}</p>
      </form>
    </div>
  ) : (
    <form onSubmit={verifyCode} className="space-y-5" noValidate aria-busy={status === "pending"}>
      <div className="space-y-2"><Label className="text-sm font-semibold text-slate-700" htmlFor="otp">{messages.codeLabel}</Label><Input className="min-h-14 rounded-xl border-slate-400 bg-white px-4 text-center text-xl tracking-[0.35em] tabular-nums rtl:tracking-[0.35em]" id="otp" name="otp" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} value={token} onChange={(event) => setToken(event.target.value.replace(/\D/g, ""))} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
      <Button className="min-h-12 w-full rounded-xl bg-blue-700 text-base hover:bg-blue-800" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.verifyCode}</Button>
      <div className="grid gap-2 sm:grid-cols-2"><button type="button" className="min-h-11 rounded-lg px-3 text-sm font-semibold text-blue-700 hover:bg-blue-50 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" disabled={status === "pending"} onClick={resendCode}>{local.resend}</button><button type="button" className="min-h-11 rounded-lg px-3 text-sm font-semibold text-slate-600 hover:bg-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" onClick={() => { setStep("email"); setToken(""); setMessage(""); }}>{messages.changeEmail}</button></div>
      <p id="auth-status" role={status === "error" ? "alert" : "status"} aria-live="polite" className={status === "error" ? "text-sm font-medium text-destructive" : "text-sm text-slate-600"}>{message}</p>
    </form>
  );
}
