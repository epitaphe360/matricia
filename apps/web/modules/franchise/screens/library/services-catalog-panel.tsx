"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import type { FranchiseCatalogRow, FranchiseCategoryNode } from "@/modules/franchise/data/library/workspace-model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { FranchiseCategoryCreateForm, FranchiseSubcategoryCreateForm } from "./catalog-commands";
import { KindChip, LanguageMarks, StatusChip, nextAction } from "./library-boards";
import { FranchiseRowMenu } from "./library-chrome";

function completeness(item: FranchiseCatalogRow) {
  return Math.round(([item.nameFr, item.nameAr, item.description].filter(Boolean).length / 3) * 100);
}

export function ServicesCatalogPanel({
  locale,
  workspaceName,
  categories,
  services,
  selectedId,
  libraryId,
  organizationId,
  commandIdentity,
}: {
  locale: Locale;
  workspaceName: string;
  categories: FranchiseCategoryNode[];
  services: FranchiseCatalogRow[];
  selectedId: string | null;
  libraryId: string;
  organizationId: string | null;
  commandIdentity: { idempotencyKey: string; correlationId: string };
}) {
  const c = libraryCopy(locale);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState("ALL");
  const [language, setLanguage] = useState("ALL");
  const [complete, setComplete] = useState("ALL");
  const [validation, setValidation] = useState("ALL");
  const [categoryId, setCategoryId] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const rows = useMemo(() => services.filter((item) => {
    if (query && !`${item.title} ${item.code}`.toLowerCase().includes(query.toLowerCase())) return false;
    if (status !== "ALL" && item.status !== status) return false;
    if (language === "FR" && !item.nameFr) return false;
    if (language === "AR" && !item.nameAr) return false;
    if (complete === "FULL" && completeness(item) < 100) return false;
    if (complete === "PARTIAL" && completeness(item) === 100) return false;
    if (validation === "DRAFT" && item.status !== "DRAFT") return false;
    if (validation === "REVIEW" && !["IN_REVIEW", "FRANCHISE_REVIEW", "CENTRAL_REVIEW"].includes(item.status)) return false;
    if (validation === "PUBLISHED" && item.status !== "PUBLISHED" && item.status !== "APPROVED") return false;
    if (categoryId) {
      const parent = categories.find((node) => node.id === categoryId);
      if (parent) {
        if (item.category !== parent.title) return false;
      } else if (item.subcategoryId !== categoryId) {
        return false;
      }
    }
    return true;
  }), [services, query, status, language, complete, validation, categoryId, categories]);
  useEffect(() => {
    setPage(1);
  }, [query, status, language, complete, validation, categoryId]);
  const pageCount = Math.max(1, Math.ceil(rows.length / 8) || 1);
  const safePage = Math.min(page, pageCount);
  const paged = rows.slice((safePage - 1) * 8, safePage * 8);

  return (
    <>
      <article className="client-card">
        <header><h2>{c.catalogTree}</h2></header>
        <p className="client-access-note">{workspaceName}</p>
        <label className="franchise-search">
          <span className="sr-only">{c.searchService}</span>
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={c.searchService} />
        </label>
        {categories.length === 0 ? <p>{c.emptyCategories}</p> : (
          <ul className="franchise-tree">
            {categories.map((category) => (
              <li key={category.id}>
                <button type="button" className="franchise-tree-btn" data-selected={categoryId === category.id ? "true" : undefined} onClick={() => setCategoryId(category.id)}>
                  {category.title}
                </button>
                <ul>
                  {category.children.map((child) => (
                    <li key={child.id}>
                      <button type="button" className="franchise-tree-btn" data-selected={categoryId === child.id ? "true" : undefined} onClick={() => setCategoryId(child.id)}>
                        {child.title}
                      </button>
                    </li>
                  ))}
                </ul>
              </li>
            ))}
          </ul>
        )}
        <details className="franchise-builder" open={categories.length === 0}>
          <summary>{c.createCategory}</summary>
          <FranchiseCategoryCreateForm locale={locale} libraryId={libraryId} organizationId={organizationId} commandIdentity={commandIdentity} />
        </details>
        <details className="franchise-builder">
          <summary>{c.createSubcategory}</summary>
          <FranchiseSubcategoryCreateForm locale={locale} libraryId={libraryId} organizationId={organizationId} commandIdentity={commandIdentity} categories={categories} />
        </details>
      </article>
      <article className="client-card">
        <header className="client-priority-head">
          <h2>{c.filterServices}</h2>
          <button type="button" className="client-soft-link" onClick={() => { setQuery(""); setStatus("ALL"); setLanguage("ALL"); setComplete("ALL"); setValidation("ALL"); setCategoryId(null); }}>{c.resetFilters}</button>
        </header>
        <div className="franchise-filters">
          <label><span className="sr-only">{c.state}</span>
            <select value={status} onChange={(event) => setStatus(event.target.value)}>
              <option value="ALL">{c.allStatuses}</option>
              <option value="DRAFT">{c.drafts}</option>
              <option value="IN_REVIEW">{c.inReview}</option>
              <option value="PUBLISHED">{c.published}</option>
            </select>
          </label>
          <label><span className="sr-only">{c.language}</span>
            <select value={language} onChange={(event) => setLanguage(event.target.value)}>
              <option value="ALL">{c.language}</option>
              <option value="FR">FR</option>
              <option value="AR">AR</option>
            </select>
          </label>
          <label><span className="sr-only">{c.completeness}</span>
            <select value={complete} onChange={(event) => setComplete(event.target.value)}>
              <option value="ALL">{c.completeness}</option>
              <option value="FULL">100%</option>
              <option value="PARTIAL">0–99%</option>
            </select>
          </label>
          <label><span className="sr-only">{c.validation}</span>
            <select value={validation} onChange={(event) => setValidation(event.target.value)}>
              <option value="ALL">{c.validation}</option>
              <option value="DRAFT">{c.drafts}</option>
              <option value="REVIEW">{c.inReview}</option>
              <option value="PUBLISHED">{c.published}</option>
            </select>
          </label>
        </div>
        {rows.length === 0 ? <p>{c.emptyServices}</p> : (
          <div className="client-table-wrap client-compare">
            <table className="client-space-table">
                <thead>
                  <tr>
                    <th><span className="sr-only">{c.rowActions}</span></th>
                    <th>{c.serviceKind}</th>
                  <th>{c.category}</th>
                  <th>{c.subcategory}</th>
                  <th>{c.version}</th>
                  <th>{c.languages}</th>
                  <th>{c.completeness}</th>
                  <th>{c.state}</th>
                    <th>{c.next}</th>
                    <th><span className="sr-only">{c.rowActions}</span></th>
                  </tr>
                </thead>
                <tbody>
                  {paged.map((item) => (
                    <tr key={item.id} data-selected={selectedId === item.id ? "true" : undefined}>
                      <td><input type="checkbox" aria-label={item.title} /></td>
                      <td><Link href={item.href}><strong>{item.title}</strong></Link><div><KindChip kind={item.kind} locale={locale} /></div></td>
                    <td>{item.category ?? "—"}</td>
                    <td>{item.subcategory ?? "—"}</td>
                    <td>{item.versionLabel ?? "—"}</td>
                    <td><LanguageMarks item={item} /></td>
                    <td>
                      <span className="franchise-complete" aria-label={`${completeness(item)}%`}><span style={{ width: `${completeness(item)}%` }} /></span>
                      <small dir="ltr">{completeness(item)}%</small>
                    </td>
                    <td><StatusChip status={item.status} locale={locale} /></td>
                      <td><Link href={item.href}>{nextAction(item.status, locale)}</Link></td>
                      <td><FranchiseRowMenu href={item.href} label={item.title} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        <nav className="franchise-pagination" aria-label={c.page}>
          {Array.from({ length: pageCount }, (_, index) => index + 1).map((n) => (
            n === safePage
              ? <span key={n} aria-current="page">{n}</span>
              : <button key={n} type="button" onClick={() => setPage(n)}>{n}</button>
          ))}
        </nav>
        <p className="client-access-note">{c.clientsNote}</p>
      </article>
    </>
  );
}
