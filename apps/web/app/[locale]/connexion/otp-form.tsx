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

export function OtpForm({ locale, nextPath }: { locale: Locale; nextPath?: string }) {
  const messages = getDictionary(locale).auth;
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
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-2" role="group" aria-label={messages.methodLabel}>
        <Button type="button" variant="outline" onClick={() => selectMethod("otp")}>{messages.otpMethod}</Button>
        <Button type="button" aria-pressed="true">{messages.passwordMethod}</Button>
      </div>
      <form onSubmit={signInWithPassword} className="space-y-5" noValidate>
        <div className="space-y-2"><Label htmlFor="email">{messages.emailLabel}</Label><Input id="email" name="email" type="email" autoComplete="username" inputMode="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder={messages.emailPlaceholder} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
        <div className="space-y-2"><Label htmlFor="password">{messages.passwordLabel}</Label><Input id="password" name="password" type="password" autoComplete="current-password" minLength={12} maxLength={72} value={password} onChange={(event) => setPassword(event.target.value)} aria-describedby="password-hint auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /><p id="password-hint" className="text-xs text-muted-foreground">{messages.passwordHint}</p></div>
        <Button className="w-full" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.signInWithPassword}</Button>
        <p id="auth-status" role="status" aria-live="polite" className={status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{message}</p>
      </form>
    </div>
  );

  return step === "email" ? (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-2" role="group" aria-label={messages.methodLabel}>
        <Button type="button" aria-pressed="true">{messages.otpMethod}</Button>
        <Button type="button" variant="outline" onClick={() => selectMethod("password")}>{messages.passwordMethod}</Button>
      </div>
      <form onSubmit={requestCode} className="space-y-5" noValidate>
      <div className="space-y-2"><Label htmlFor="email">{messages.emailLabel}</Label><Input id="email" name="email" type="email" autoComplete="email" inputMode="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder={messages.emailPlaceholder} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
      <Button className="w-full" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.requestCode}</Button>
      <p id="auth-status" role="status" aria-live="polite" className={status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{message}</p>
      </form>
    </div>
  ) : (
    <form onSubmit={verifyCode} className="space-y-5" noValidate>
      <div className="space-y-2"><Label htmlFor="otp">{messages.codeLabel}</Label><Input id="otp" name="otp" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} value={token} onChange={(event) => setToken(event.target.value.replace(/\D/g, ""))} aria-describedby="auth-status" aria-invalid={status === "error"} aria-errormessage={status === "error" ? "auth-status" : undefined} required /></div>
      <Button className="w-full" disabled={status === "pending"} type="submit">{status === "pending" ? messages.pending : messages.verifyCode}</Button>
      <button type="button" className="w-full text-sm font-medium text-primary underline-offset-4 hover:underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2" onClick={() => { setStep("email"); setToken(""); setMessage(""); }}>{messages.changeEmail}</button>
      <p id="auth-status" role="status" aria-live="polite" className={status === "error" ? "text-sm text-destructive" : "text-sm text-muted-foreground"}>{message}</p>
    </form>
  );
}
