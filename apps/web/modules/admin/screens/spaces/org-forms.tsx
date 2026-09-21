"use client";

import { useActionState, useMemo, type ReactNode } from "react";
import Link from "next/link";
import { adminCopy } from "@/modules/admin/data/spaces/copy";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { requestOrganizationMutation, type AdminActionState } from "./org-actions";

const idle: AdminActionState = { status: "idle" };

function Field({
  id,
  label,
  required,
  error,
  children,
  span,
}: {
  id: string;
  label: string;
  required?: boolean;
  error?: string;
  children: ReactNode;
  span?: boolean;
}) {
  return (
    <div className="admin-field" data-span={span ? "2" : undefined} data-invalid={error ? "true" : undefined}>
      <label htmlFor={id}>{label}{required ? " *" : ""}</label>
      {children}
      {error ? <p className="admin-error">{error}</p> : null}
    </div>
  );
}

function Feedback({ state, locale }: { state: AdminActionState; locale: Locale }) {
  const c = adminCopy(locale);
  if (state.status === "success") return <p role="status">{locale === "ar" ? "تم تسجيل الطلب للمصادقة." : "Demande enregistrée pour validation à quatre yeux."}</p>;
  if (state.status !== "error") return null;
  if (state.reason === "CONFLICT") return <p role="alert" className="admin-error">{c.conflictLead}</p>;
  return <p role="alert" className="admin-error">{state.reason}</p>;
}

export function CreateOrganizationForm({ locale, query }: { locale: Locale; query: string }) {
  const c = adminCopy(locale);
  const [state, action, pending] = useActionState(requestOrganizationMutation, idle);
  return (
    <form action={action} className="admin-form-layout">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="intent" value="CREATE_ORGANIZATION" />
      <div className="client-stack">
        <article className="client-card">
          <header><h2>{c.general}</h2></header>
          <div className="admin-form-grid">
            <Field id="create-name" label={c.name} required>
              <input id="create-name" name="displayName" required minLength={2} />
            </Field>
            <Field id="create-legal" label={c.legal} required>
              <input id="create-legal" name="legalName" required minLength={2} />
            </Field>
            <Field id="create-ice" label={c.iceLabel} required>
              <input id="create-ice" name="ice" required minLength={8} dir="ltr" />
            </Field>
            <Field id="create-kind" label={c.ownerKind} required>
              <select id="create-kind" name="kind" required defaultValue="CLIENT">
                <option value="CLIENT">{c.kindClient}</option>
                <option value="PROVIDER">{c.kindProvider}</option>
                <option value="FRANCHISE">{c.kindFranchise}</option>
              </select>
            </Field>
            <Field id="create-reason" label={c.reason} required span>
              <textarea id="create-reason" name="reason" required minLength={10} />
            </Field>
          </div>
        </article>
        <div className="admin-form-foot">
          <Link href={`/${locale}/administration/entreprises${query}`} className="client-ghost-link">{c.cancel}</Link>
          <button type="submit" className="admin-primary-cta" disabled={pending}>{pending ? "…" : c.createSubmit}</button>
        </div>
        <Feedback state={state} locale={locale} />
      </div>
      <aside className="client-card">
        <header><h2>{c.fourEyes}</h2></header>
        <p>{c.createLead}</p>
      </aside>
    </form>
  );
}

export function EditOrganizationForm({
  locale,
  query,
  organizationId,
  displayName,
  legalName,
  status,
  country,
  updatedAt,
}: {
  locale: Locale;
  query: string;
  organizationId: string;
  displayName: string;
  legalName: string;
  status: string;
  country: string;
  updatedAt: string | null;
}) {
  const c = adminCopy(locale);
  const [state, action, pending] = useActionState(requestOrganizationMutation, idle);
  const conflict = state.status === "error" && state.reason === "CONFLICT";
  const errors = state.status === "error" && state.reason === "VALIDATION";
  const changed = useMemo(() => [c.name, c.address, c.email, c.state], [c.address, c.email, c.name, c.state]);
  return (
    <form action={action} className="admin-form-layout">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="intent" value="CHANGE_CONFIGURATION" />
      <input type="hidden" name="organizationId" value={organizationId} />
      <input type="hidden" name="resourceId" value={organizationId} />
      <div className="client-stack">
        {conflict ? (
          <div className="admin-banner" data-tone="warn">
            <strong>{c.conflictTitle}</strong>
            <p>{c.conflictLead}</p>
            <div className="admin-empty-actions">
              <a href={`/${locale}/administration/entreprises/${organizationId}/modifier${query}`} className="admin-soft-cta">{c.reload}</a>
              <Link href={`/${locale}/administration/entreprises/${organizationId}${query}`} className="client-ghost-link">{c.compare}</Link>
            </div>
          </div>
        ) : null}
        {errors ? (
          <div className="admin-banner" data-tone="danger">
            <strong>{c.errorsTitle} (2)</strong>
            <ul>
              <li>{c.email} — {c.requiredField}</li>
              <li>{c.reasonRequired}</li>
            </ul>
          </div>
        ) : null}
        <article className="client-card">
          <header><h2>{c.general}</h2></header>
          <div className="admin-form-grid" data-cols="3">
            <Field id="edit-name" label={c.name} required>
              <input id="edit-name" name="displayName" required defaultValue={displayName} />
            </Field>
            <Field id="edit-acronym" label={c.acronym}>
              <input id="edit-acronym" name="acronym" />
            </Field>
            <Field id="edit-desc" label={c.description}>
              <input id="edit-desc" name="description" defaultValue={legalName} />
            </Field>
          </div>
        </article>
        <article className="client-card">
          <header><h2>{c.location}</h2></header>
          <div className="admin-form-grid" data-cols="3">
            <Field id="edit-address" label={c.address} required span>
              <input id="edit-address" name="address" required />
            </Field>
            <Field id="edit-city" label={c.city}>
              <input id="edit-city" name="city" />
            </Field>
            <Field id="edit-zip" label={c.zip}>
              <input id="edit-zip" name="postalCode" dir="ltr" />
            </Field>
            <Field id="edit-country" label={c.country}>
              <input id="edit-country" name="country" defaultValue={country} />
            </Field>
            <Field id="edit-phone" label={c.phone}>
              <input id="edit-phone" name="phone" dir="ltr" />
            </Field>
            <Field id="edit-email" label={c.email} required error={errors ? c.requiredField : undefined}>
              <input id="edit-email" name="email" type="email" required />
            </Field>
            <Field id="edit-web" label={c.web}>
              <input id="edit-web" name="website" dir="ltr" />
            </Field>
          </div>
        </article>
        <article className="client-card">
          <header><h2>{c.legalBlock}</h2></header>
          <div className="admin-form-grid" data-cols="3">
            <Field id="edit-form" label={c.legalForm}>
              <input id="edit-form" name="legalForm" />
            </Field>
            <Field id="edit-ice" label={c.ice}>
              <input id="edit-ice" name="ice" dir="ltr" />
            </Field>
            <Field id="edit-tax" label={c.tax}>
              <input id="edit-tax" name="tax" disabled value={c.restrictedValue} aria-label={c.accessRestricted} />
              <small>{c.taxNote}</small>
            </Field>
          </div>
        </article>
        <article className="client-card">
          <header><h2>{c.params}</h2></header>
          <div className="admin-form-grid" data-cols="3">
            <Field id="edit-status" label={c.state} required>
              <input id="edit-status" name="status" required defaultValue={status} />
            </Field>
            <Field id="edit-level" label={c.adminLevel}>
              <input id="edit-level" name="adminLevel" />
            </Field>
            <Field id="edit-parent" label={c.parent}>
              <input id="edit-parent" name="parent" />
            </Field>
            <Field id="edit-reason" label={c.reason} required span>
              <textarea id="edit-reason" name="reason" required minLength={10} placeholder={c.reason} />
            </Field>
          </div>
        </article>
        <div className="admin-form-foot">
          <Link href={`/${locale}/administration/entreprises/${organizationId}${query}`} className="client-ghost-link">{c.cancel}</Link>
          <button type="submit" className="admin-soft-cta" name="draft" value="1" disabled={pending}>{c.saveDraft}</button>
          <button type="submit" className="admin-primary-cta" disabled={pending}>{pending ? "…" : c.submit}</button>
        </div>
        <Feedback state={state} locale={locale} />
      </div>
      <aside className="client-stack">
        <article className="client-card">
          <header><h2>{c.summary}</h2><p>{c.summaryLead}</p></header>
          <ul className="admin-impact">
            {changed.map((item) => <li key={item}>{item}</li>)}
          </ul>
        </article>
        <article className="client-card">
          <header><h2>{c.impact}</h2></header>
          <ul className="admin-impact">
            <li>{c.impact1}</li>
            <li>{c.impact2}</li>
            <li>{c.impact3}</li>
            <li>{c.impact4}</li>
            <li>{c.impact5}</li>
          </ul>
          <p className="client-access-note">{c.impactNote}</p>
        </article>
        <article className="client-card">
          <header><h2>{c.lastChange}</h2></header>
          <p>{updatedAt ?? c.lastChangeLead}</p>
        </article>
      </aside>
    </form>
  );
}

export function ArchiveOrganizationForm({
  locale,
  query,
  organizationId,
  displayName,
  status,
  mode,
}: {
  locale: Locale;
  query: string;
  organizationId: string;
  displayName: string;
  status: string;
  mode: "archive" | "disable";
}) {
  const c = adminCopy(locale);
  const [state, action, pending] = useActionState(requestOrganizationMutation, idle);
  const archive = mode === "archive";
  return (
    <form action={action} className="admin-archive-layout">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="intent" value={archive ? "SUSPEND_ENTITY" : "RESTRICT_ENTITY"} />
      <input type="hidden" name="organizationId" value={organizationId} />
      <input type="hidden" name="resourceId" value={organizationId} />
      <div className="client-stack">
        <article className="client-card">
          <header><h2>{c.concerned}</h2></header>
          <p><strong>{displayName}</strong></p>
          <p>{archive ? c.willArchive : c.disableLead}</p>
          <span className="admin-status">{status}</span>
        </article>
        <article className="client-card">
          <header><h2>{c.archiveImpact}</h2></header>
          <ul className="admin-impact">
            <li><strong>{c.iAccess}</strong><br />{c.iAccessLead}</li>
            <li><strong>{c.iWork}</strong><br />{c.iWorkLead}</li>
            <li><strong>{c.iUsers}</strong><br />{c.iUsersLead}</li>
            <li><strong>{c.iDocs}</strong><br />{c.iDocsLead}</li>
          </ul>
        </article>
        <article className="client-card">
          <header><h2>{c.archiveInfo}</h2></header>
          <div className="admin-form-grid">
            <Field id="archive-reason" label={c.archiveReason} required span>
              <textarea id="archive-reason" name="reason" required minLength={10} />
            </Field>
            <Field id="archive-note" label={c.note} span>
              <textarea id="archive-note" name="note" maxLength={500} />
            </Field>
          </div>
          <label className="admin-field">
            <span><input type="checkbox" name="confirmImpact" required /> {c.confirm}</span>
          </label>
          <div className="admin-banner" data-tone="danger">
            <strong>{c.fourEyes}</strong>
            <p>{c.fourEyesLead}</p>
          </div>
        </article>
        <div className="admin-form-foot">
          <Link href={`/${locale}/administration/entreprises/${organizationId}${query}`} className="client-ghost-link">{c.cancel}</Link>
          <button type="submit" className="admin-danger-cta" disabled={pending}>{pending ? "…" : archive ? c.confirmArchive : c.confirmDisable}</button>
        </div>
        <Feedback state={state} locale={locale} />
      </div>
      <aside className="client-stack">
        <article className="client-card">
          <header><h2>{c.restore}</h2></header>
          <p>{c.restoreLead}</p>
          <div className="admin-restore-note">
            <strong>{c.restoreAuth}</strong>
            <p>{c.restoreAuthLead}</p>
          </div>
          <p className="client-access-note">{c.restoreHint}</p>
        </article>
        <article className="client-card">
          <header><h2>{c.diffs}</h2></header>
          <div className="admin-diff">
            <article><h3>{c.dDisable}</h3><p>{c.dDisableLead}</p></article>
            <article><h3>{c.dArchive}</h3><p>{c.dArchiveLead}</p></article>
            <article><h3>{c.dRestore}</h3><p>{c.dRestoreLead}</p></article>
            <article data-tone="danger"><h3>{c.dDelete}</h3><p>{c.dDeleteLead}</p></article>
          </div>
        </article>
        <article className="client-card">
          <header><h2>{c.auditPreview}</h2></header>
          <dl className="admin-dl">
            <div><dt>{c.event}</dt><dd>{c.eventArchive}</dd></div>
            <div><dt>{c.ref}</dt><dd dir="ltr">{organizationId}</dd></div>
            <div><dt>{c.actor}</dt><dd>{c.actorYou}</dd></div>
            <div><dt>{c.stamped}</dt><dd>{c.nowStamp}</dd></div>
            <div><dt>{c.details}</dt><dd>{displayName}</dd></div>
          </dl>
          <Link href={`/${locale}/administration/operations${query}`} className="client-soft-link">{c.seeJournal}</Link>
          <p className="client-access-note">{c.auditFoot}</p>
        </article>
      </aside>
    </form>
  );
}
