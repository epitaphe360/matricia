"use client";

import { useActionState, useId } from "react";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Label } from "@/modules/shared/ui/label";
import { Textarea } from "@/modules/shared/ui/textarea";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import type { FranchiseCatalogRow, FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import {
  createFranchiseServiceAction,
  saveFranchiseServiceDraftAction,
  simulateFranchiseServiceImpactAction,
  submitFranchiseCatalogServiceAction,
  type FranchiseServiceActionState,
} from "./actions";

const initialState: FranchiseServiceActionState = { status: "idle" };

export function FranchiseServiceDraftForm({
  locale,
  workspace,
  commandIdentity,
  organizationId,
}: {
  locale: Locale;
  workspace: FranchiseLibraryWorkspace;
  commandIdentity: { idempotencyKey: string; correlationId: string };
  organizationId: string | null;
}) {
  const c = libraryCopy(locale);
  const [state, action, pending] = useActionState(createFranchiseServiceAction, initialState);
  const prefix = useId();
  const subcategories = workspace.categories.flatMap((category) => category.children.map((child) => ({ ...child, category: category.title })));
  const error = state.status === "error"
    ? state.reason === "VALIDATION" ? (locale === "ar" ? "تحققوا من الحقول الإلزامية بالفرنسية والعربية." : "Complétez les champs obligatoires en FR et AR.")
      : state.reason === "FORBIDDEN" ? c.forbidden
        : c.unavailable
    : null;
  if (subcategories.length === 0) return <p>{c.emptySubcategories}</p>;
  return (
    <form action={action} className="franchise-props-form" aria-describedby={`${prefix}-status`}>
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="libraryId" value={workspace.mandate.libraryId} />
      {organizationId ? <input type="hidden" name="organizationId" value={organizationId} /> : null}
      <input type="hidden" name="idempotencyKey" defaultValue={commandIdentity.idempotencyKey} />
      <input type="hidden" name="correlationId" defaultValue={commandIdentity.correlationId} />
      <div>
        <Label htmlFor={`${prefix}-fr`}>{c.servicesTitle} (FR)</Label>
        <Input id={`${prefix}-fr`} name="nameFr" required maxLength={240} dir="ltr" className="min-h-11" />
      </div>
      <div>
        <Label htmlFor={`${prefix}-ar`}>{c.servicesTitle} (AR)</Label>
        <Input id={`${prefix}-ar`} name="nameAr" required maxLength={240} dir="rtl" lang="ar" className="min-h-11" />
      </div>
      <div>
        <Label htmlFor={`${prefix}-code`}>{c.technicalKey}</Label>
        <Input id={`${prefix}-code`} name="code" required pattern="[A-Z][A-Z0-9_-]{1,79}" dir="ltr" className="min-h-11 font-mono" />
      </div>
      <div>
        <Label htmlFor={`${prefix}-sub`}>{c.linked}</Label>
        <select id={`${prefix}-sub`} name="subcategoryId" required className="min-h-11 w-full rounded-md border border-input bg-background px-3">
          {subcategories.map((item) => <option key={item.id} value={item.id}>{item.category} / {item.title}</option>)}
        </select>
      </div>
      <div>
        <Label htmlFor={`${prefix}-desc-fr`}>{locale === "ar" ? "الوصف (FR)" : "Description (FR)"}</Label>
        <Textarea id={`${prefix}-desc-fr`} name="descriptionFr" required maxLength={1000} dir="ltr" />
      </div>
      <div>
        <Label htmlFor={`${prefix}-desc-ar`}>{locale === "ar" ? "الوصف (AR)" : "Description (AR)"}</Label>
        <Textarea id={`${prefix}-desc-ar`} name="descriptionAr" required maxLength={1000} dir="rtl" lang="ar" />
      </div>
      <div>
        <Label htmlFor={`${prefix}-reason`}>{locale === "ar" ? "سبب التغيير" : "Motif de la version"}</Label>
        <Input id={`${prefix}-reason`} name="changeReason" required minLength={3} maxLength={500} className="min-h-11" />
      </div>
      <label className="flex min-h-11 items-start gap-3 rounded-lg border p-3 text-sm">
        <input className="mt-0.5 size-5" type="checkbox" name="confirmed" value="yes" required />
        <span>{c.submitValidation} · {c.scope}</span>
      </label>
      <Button type="submit" disabled={pending} className="min-h-11">{pending ? c.saveDraft : c.newService}</Button>
      <div id={`${prefix}-status`} role={error ? "alert" : "status"} aria-live="polite">{error ?? (state.status === "success" ? c.serviceCreated : null)}</div>
    </form>
  );
}

function actionMessage(state: FranchiseServiceActionState, locale: Locale, success: string) {
  const c = libraryCopy(locale);
  if (state.status === "error") {
    if (state.reason === "VALIDATION") return locale === "ar" ? "تحققوا من الحقول الإلزامية بالفرنسية والعربية." : "Complétez les champs obligatoires en FR et AR.";
    if (state.reason === "FORBIDDEN") return c.forbidden;
    if (state.reason === "CONFLICT") return c.conflict;
    if (state.reason === "LOCKED") return c.locked;
    return c.unavailable;
  }
  if (state.status === "success") return success;
  return null;
}

export function FranchiseServiceCommandForms({
  locale,
  workspace,
  service,
  commandIdentity,
  organizationId,
}: {
  locale: Locale;
  workspace: FranchiseLibraryWorkspace;
  service: FranchiseCatalogRow;
  commandIdentity: { idempotencyKey: string; correlationId: string };
  organizationId: string | null;
}) {
  const c = libraryCopy(locale);
  const command = service.command;
  const [saveState, saveAction, savePending] = useActionState(saveFranchiseServiceDraftAction, initialState);
  const [simState, simAction, simPending] = useActionState(simulateFranchiseServiceImpactAction, initialState);
  const [submitState, submitAction, submitPending] = useActionState(submitFranchiseCatalogServiceAction, initialState);
  const prefix = useId();
  if (!command) return null;
  const subcategories = workspace.categories.flatMap((category) => category.children.map((child) => ({ ...child, category: category.title })));
  const draft = service.status === "DRAFT";
  const editable = service.status !== "IN_REVIEW";
  const hidden = (
    <>
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="libraryId" value={workspace.mandate.libraryId} />
      {organizationId ? <input type="hidden" name="organizationId" value={organizationId} /> : null}
      <input type="hidden" name="serviceId" value={service.id} />
      <input type="hidden" name="draftVersionId" value={command.draftVersionId} />
      <input type="hidden" name="identityRowVersion" value={String(command.identityRowVersion)} />
      <input type="hidden" name="versionRowVersion" value={String(command.versionRowVersion)} />
    </>
  );
  return (
    <div className="franchise-command-stack">
      <form id={`${prefix}-save`} action={saveAction} className="franchise-props-form" aria-describedby={`${prefix}-save-status`}>
        {hidden}
        <input type="hidden" name="idempotencyKey" defaultValue={commandIdentity.idempotencyKey} />
        <input type="hidden" name="correlationId" defaultValue={commandIdentity.correlationId} />
        <input type="hidden" name="code" value={service.code} />
        <div>
          <Label htmlFor={`${prefix}-fr`}>{c.labelFr}</Label>
          <Input id={`${prefix}-fr`} name="nameFr" required maxLength={240} dir="ltr" className="min-h-11" defaultValue={service.nameFr ?? ""} readOnly={!editable} />
        </div>
        <div>
          <Label htmlFor={`${prefix}-ar`}>{c.labelAr}</Label>
          <Input id={`${prefix}-ar`} name="nameAr" required maxLength={240} dir="rtl" lang="ar" className="min-h-11" defaultValue={service.nameAr ?? ""} readOnly={!editable} />
        </div>
        <div>
          <Label htmlFor={`${prefix}-sub`}>{c.linked}</Label>
          <select id={`${prefix}-sub`} name="subcategoryId" required className="min-h-11 w-full rounded-md border border-input bg-background px-3" defaultValue={service.subcategoryId ?? ""} disabled={!editable}>
            {subcategories.map((item) => <option key={item.id} value={item.id}>{item.category} / {item.title}</option>)}
          </select>
          {!editable ? <input type="hidden" name="subcategoryId" value={service.subcategoryId ?? ""} /> : null}
        </div>
        <div>
          <Label htmlFor={`${prefix}-desc-fr`}>{c.helpFr}</Label>
          <Textarea id={`${prefix}-desc-fr`} name="descriptionFr" required maxLength={1000} dir="ltr" defaultValue={command.descriptionFr} readOnly={!editable} />
        </div>
        <div>
          <Label htmlFor={`${prefix}-desc-ar`}>{c.helpAr}</Label>
          <Textarea id={`${prefix}-desc-ar`} name="descriptionAr" required maxLength={1000} dir="rtl" lang="ar" defaultValue={command.descriptionAr} readOnly={!editable} />
        </div>
        <div>
          <Label htmlFor={`${prefix}-reason`}>{locale === "ar" ? "سبب التغيير" : "Motif de la version"}</Label>
          <Input id={`${prefix}-reason`} name="changeReason" required minLength={3} maxLength={500} className="min-h-11" defaultValue={locale === "ar" ? "تحديث المسودة" : "Mise à jour du brouillon"} />
        </div>
        {editable ? <Button type="submit" disabled={savePending} className="min-h-11">{c.saveDraft}</Button> : null}
        <div id={`${prefix}-save-status`} role={saveState.status === "error" ? "alert" : "status"} aria-live="polite">{actionMessage(saveState, locale, c.serviceSaved)}</div>
      </form>
      <form action={simAction} className="franchise-props-form">
        {hidden}
        <input type="hidden" name="idempotencyKey" defaultValue={`${commandIdentity.idempotencyKey.slice(0, 14)}a${commandIdentity.idempotencyKey.slice(15)}`} />
        <input type="hidden" name="correlationId" defaultValue={commandIdentity.correlationId} />
        <Button type="submit" disabled={simPending} className="min-h-11" variant="outline">{c.runSimulation}</Button>
        <div role={simState.status === "error" ? "alert" : "status"} aria-live="polite">{actionMessage(simState, locale, c.impactSimulated)}</div>
      </form>
      {draft ? (
        <form action={submitAction} className="franchise-props-form">
          {hidden}
          <input type="hidden" name="idempotencyKey" defaultValue={`${commandIdentity.idempotencyKey.slice(0, 14)}b${commandIdentity.idempotencyKey.slice(15)}`} />
          <input type="hidden" name="correlationId" defaultValue={commandIdentity.correlationId} />
          <label className="flex min-h-11 items-start gap-3 rounded-lg border p-3 text-sm">
            <input className="mt-0.5 size-5" type="checkbox" name="confirmed" value="yes" required />
            <span>{c.submitMatricia} · {c.scope}</span>
          </label>
          <Button type="submit" disabled={submitPending} className="min-h-11">{c.submitMatricia}</Button>
          <div role={submitState.status === "error" ? "alert" : "status"} aria-live="polite">{actionMessage(submitState, locale, c.serviceSubmitted)}</div>
        </form>
      ) : service.status === "APPROVED" ? (
        <p className="client-access-note">{c.publishSnapshot} · {c.publishedImmutable}</p>
      ) : <p className="client-access-note">{service.status === "PUBLISHED" ? c.publishedImmutable : c.locked}</p>}
    </div>
  );
}
