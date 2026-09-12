import type { ComponentPropsWithoutRef } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/components/ui/button", () => ({ Button: ({ children, ...props }: ComponentPropsWithoutRef<"button">) => <button {...props}>{children}</button> }));
vi.mock("@/components/ui/input", () => ({ Input: (props: ComponentPropsWithoutRef<"input">) => <input {...props} /> }));
vi.mock("@/components/ui/label", () => ({ Label: ({ children, ...props }: ComponentPropsWithoutRef<"label">) => <label {...props}>{children}</label> }));
vi.mock("@/lib/franchise-digest/model", async () => await import("../../../../lib/franchise-digest/model"));
vi.mock("./actions", () => ({ configureDigest: async () => ({ status: "idle" }) }));

import { FranchiseDigestPanel } from "./digest-panel";
import { getFranchiseDigestMessages } from "./messages";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
const dashboard = { currentUserId: id(1), franchises: [{ id: id(2), territoryCode: "MA", territoryNameFr: "Maroc", territoryNameAr: "المغرب", mandateVersion: 3 }], configurations: [], digests: [{ id: id(3), franchise_id: id(2), digest_date: "2026-09-12", locale: "fr-MA" as const, generated_at: "2026-09-12T08:00:00Z", metrics_snapshot: { policy_version: 1, crm: { total_prospects: 12, client_prospects: 7, provider_prospects: 5, pipeline: {} }, followups: { overdue: 2, next_24_hours: 3 }, performance: { global_score_basis_points: 8500, library_quality_score_basis_points: 9000, health_suggestion: "HEALTHY", period_end: "2026-09-11" }, alerts: { open_total: 1, critical: 0, warning: 1 }, objectives: { active: 2, overdue: 0, due_today: 1 } } }], jobs: [{ id: id(4), digest_id: id(3), franchise_id: id(2), recipient_user_id: id(1), status: "NOTIFIED" as const, attempt_count: 1, next_attempt_at: null, last_error_code: null, updated_at: "2026-09-12T08:01:00Z" }] };

describe("FranchiseDigestPanel", () => {
  it("associates every visible form control with a label and live feedback", () => { const html = renderToStaticMarkup(<FranchiseDigestPanel dashboard={dashboard} locale="fr" m={getFranchiseDigestMessages("fr")} keys={{ [id(2)]: id(5) }} />); const controls = [...html.matchAll(/<(?:input|select|textarea)[^>]*\sid="([^"]+)"/g)].map((match) => match[1]), labels = [...html.matchAll(/<label[^>]+for="([^"]+)"/g)].map((match) => match[1]); expect(labels.filter((label) => !controls.includes(label))).toEqual([]); expect(html).toContain('aria-live="polite"'); expect(html).toContain("Franchise"); expect(html).not.toMatch(/personne@example|0612345678|rue privée|HATIM_AHMITECH/i); });
  it("renders native Arabic RTL content in a 360px-fluid layout", () => { const html = renderToStaticMarkup(<div dir="rtl" lang="ar"><FranchiseDigestPanel dashboard={dashboard} locale="ar" m={getFranchiseDigestMessages("ar")} keys={{ [id(2)]: id(5) }} /></div>); expect(html).toContain('dir="rtl"'); expect(html).toContain("المغرب"); expect(html).toContain("w-full sm:w-auto"); expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/); });
  it("renders explicit empty states", () => { const html = renderToStaticMarkup(<FranchiseDigestPanel dashboard={{ ...dashboard, digests: [], jobs: [] }} locale="fr" m={getFranchiseDigestMessages("fr")} keys={{ [id(2)]: id(5) }} />); expect(html).toContain("Aucun résumé agrégé"); expect(html).toContain("Aucun acheminement"); });
});
