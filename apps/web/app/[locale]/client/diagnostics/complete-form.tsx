"use client";

import { useActionState } from "react";
import { Button } from "@/components/ui/button";
import { completeLatestAction, idle } from "./actions";
import type { Messages } from "./messages";

export function CompleteForm({ locale, organizations, m, keyValue }: { locale: "fr" | "ar"; organizations: readonly { id: string; name: string; latestAt: string }[]; m: Messages; keyValue: string }) {
  const [state, action, pending] = useActionState(completeLatestAction, idle);
  const hasSubmittedAssessment = organizations.length > 0;
  return <form action={action} className="space-y-4 rounded-xl border bg-card p-4 sm:p-5">
    <input type="hidden" name="locale" value={locale} />
    <input type="hidden" name="idempotencyKey" value={keyValue} />
    {organizations.length === 1 ? <input type="hidden" name="organizationId" value={organizations[0]!.id} /> : organizations.length > 1 ? <label className="block font-medium">{locale === "fr" ? "Entreprise concernée" : "المؤسسة المعنية"}<select name="organizationId" required className="mt-2 min-h-11 w-full rounded-md border bg-background px-3">{organizations.map((organization) => <option key={organization.id} value={organization.id}>{organization.name} · {new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(organization.latestAt))}</option>)}</select></label> : null}
    <div><h2 className="text-xl font-semibold">{m.prepareTitle}</h2><p className="mt-2 max-w-3xl text-sm leading-6 text-muted-foreground">{hasSubmittedAssessment ? m.prepareDescription : m.noSubmittedAssessment}</p></div>
    {hasSubmittedAssessment ? <label className="flex min-h-11 items-start gap-3 rounded-lg border p-3"><input type="checkbox" name="confirmSnapshot" value="CONFIRMED" required className="mt-0.5 size-5 shrink-0" /><span><strong>{m.confirmAnalysis}</strong><span className="mt-1 block text-sm text-muted-foreground">{m.recalculationNote}</span></span></label> : null}
    {state.status === "error" ? <p role="alert" className="text-sm text-destructive">{state.reason === "VALIDATION" ? m.validation : state.reason === "NO_SUBMITTED_ASSESSMENT" ? m.noSubmittedAssessment : state.reason === "ANALYSIS_SCOPE_REQUIRED" ? m.analysisScopeRequired : m.error}</p> : null}
    {state.status === "success" ? <p role="status" className="text-sm text-primary">{m.success}</p> : null}
    {hasSubmittedAssessment ? <Button disabled={pending} className="min-h-11 w-full sm:w-auto">{pending ? m.calculating : m.complete}</Button> : null}
  </form>;
}
