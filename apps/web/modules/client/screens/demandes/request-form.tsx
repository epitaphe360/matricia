"use client";

import { useActionState } from "react";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Textarea } from "@/modules/shared/ui/textarea";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import type { ClientRfqMessages } from "./messages";
import { createRequestAction, type ActionState } from "./actions";

const idle: ActionState = { status: "idle" };

type RequestFormShared = {
  organizationId: string;
  organizationName: string;
  serviceName: string;
  title: string;
  description: string;
  regionCode?: string;
  siteId?: string | null;
};

export type RequestFormContext =
  | (RequestFormShared & { source: "opportunity"; opportunityId: string })
  | (RequestFormShared & { source: "need"; intakeId: string; serviceCode: string });

export type RequestSiteOption = { id: string; nameFr: string; nameAr: string };

export function RequestForm({
  locale,
  context,
  messages,
  sites = [],
}: {
  locale: "fr" | "ar";
  context: RequestFormContext;
  messages: ClientRfqMessages;
  sites?: RequestSiteOption[];
}) {
  const [state, action, pending] = useActionState(createRequestAction, idle);
  const c = spaceCopy(locale);
  const steps = [
    { id: "need", label: c.stepNeed, hint: locale === "ar" ? "هدفكم" : "Votre objectif" },
    { id: "scope", label: c.stepScope, hint: locale === "ar" ? "تفاصيل المهمة" : "Détails de la mission" },
    { id: "constraints", label: c.stepConstraints, hint: locale === "ar" ? "آجال، ميزانية، وسائل" : "Délais, budget, moyens" },
    { id: "docs", label: c.stepDocs, hint: locale === "ar" ? "وثائق مفيدة" : "Pièces utiles" },
    { id: "recap", label: c.stepRecap, hint: locale === "ar" ? "تحقق وإرسال" : "Vérification et envoi" },
  ] as const;

  return (
    <form action={action} className="client-wizard" noValidate>
      <input type="hidden" name="locale" value={locale} />
      {context.source === "opportunity" ? (
        <input type="hidden" name="opportunityId" value={context.opportunityId} />
      ) : (
        <>
          <input type="hidden" name="intakeId" value={context.intakeId} />
          <input type="hidden" name="serviceCode" value={context.serviceCode} />
        </>
      )}
      <input type="hidden" name="organizationId" value={context.organizationId} />
      <input type="hidden" name="currency" value="MAD" />

      <ol className="client-wizard-steps">
        {steps.map((step, index) => (
          <li key={step.id} data-state={index === 0 ? "current" : "todo"}>
            <span>{index + 1}</span>
            <strong>{step.label}</strong>
            <small>{step.hint}</small>
          </li>
        ))}
      </ol>

      <div className="client-wizard-layout">
        <article className="client-card">
          <header>
            <h2>{c.wizardNeedTitle}</h2>
            <p>{c.wizardNeedLead}</p>
          </header>
          <section aria-labelledby="request-context" className="client-wizard-context">
            <h3 id="request-context">{context.title}</h3>
            <dl className="client-fact-grid">
              <div>
                <small>{messages.organization}</small>
                <span>{context.organizationName}</span>
              </div>
              <div>
                <small>{messages.suggestedSolution}</small>
                <span>{context.serviceName}</span>
              </div>
            </dl>
            <p>{messages.contextDerived}</p>
          </section>
          <div className="client-wizard-fields">
            <Field label={c.yourObjective}>
              <Textarea name="description" required minLength={10} maxLength={8000} rows={5} defaultValue={context.description} />
            </Field>
            <div className="client-wizard-grid">
              <Field label={messages.urgency}>
                <select name="urgency" defaultValue="NORMAL">
                  <option value="LOW">{messages.urgencies.LOW}</option>
                  <option value="NORMAL">{messages.urgencies.NORMAL}</option>
                  <option value="HIGH">{messages.urgencies.HIGH}</option>
                  <option value="CRITICAL">{messages.urgencies.CRITICAL}</option>
                </select>
              </Field>
              <Field label={c.desiredStart}>
                <Input type="date" name="desiredDate" />
              </Field>
              <Field label={messages.budgetAmount}>
                <Input name="budget" inputMode="decimal" dir="ltr" placeholder="15 000,00" aria-describedby="budget-help" />
                <span id="budget-help">{messages.budgetHelp}</span>
              </Field>
              <Field label={messages.companySite}>
                {sites.length === 0 ? (
                  <p>{messages.noCompanySite}</p>
                ) : (
                  <select name="siteId" defaultValue={context.siteId ?? ""}>
                    <option value="">{locale === "ar" ? "بدون موقع" : "Aucun site"}</option>
                    {sites.map((site) => (
                      <option key={site.id} value={site.id}>{locale === "ar" ? site.nameAr : site.nameFr}</option>
                    ))}
                  </select>
                )}
              </Field>
              <Field label={messages.region}>
                <Input name="regionCode" required dir="ltr" defaultValue={context.regionCode} />
              </Field>
            </div>
          </div>
          <p className="client-verified">{context.source === "need" ? c.prefilledFromNeed : c.prefilledFromBilan}</p>
          {state.status === "error" ? (
            <p role="alert">{state.reason === "VALIDATION" ? messages.validation : state.reason === "CONTEXT_REQUIRED" ? messages.contextError : state.reason === "FORBIDDEN" ? messages.notEntitled : messages.actionError}</p>
          ) : null}
          {state.status === "success" && state.requestId ? (
            <p role="status">
              {messages.saved}{" "}
              <Link href={`/${locale}/client/demandes/${state.requestId}`}>{messages.view}</Link>
            </p>
          ) : null}
          <div className="client-offer-actions">
            <Button type="submit" disabled={pending} className="client-ghost-link">
              {pending ? messages.creating : c.saveDraft}
            </Button>
            <Button type="submit" disabled={pending} className="client-cta">
              {pending ? messages.creating : c.wizardContinue}
              <ArrowRight className="size-4 rtl:rotate-180" aria-hidden />
            </Button>
          </div>
        </article>
        <aside className="client-card client-wizard-aside">
          <header>
            <h2>{c.understood}</h2>
          </header>
          <p>{c.wizardUnderstoodLead}</p>
          <dl className="client-fact-grid">
            <div>
              <small>{c.yourObjective}</small>
              <span>{context.title}</span>
            </div>
            <div>
              <small>{messages.suggestedSolution}</small>
              <span>{context.serviceName}</span>
            </div>
            <div>
              <small>{messages.companySite}</small>
              <span>{context.organizationName}</span>
            </div>
          </dl>
          <p>{c.wizardNeedLead}</p>
        </aside>
      </div>
    </form>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="client-wizard-field">
      <span>{label}</span>
      {children}
    </label>
  );
}
