import type { ComponentPropsWithoutRef } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/modules/shared/ui/button", () => ({ Button: (props: ComponentPropsWithoutRef<"button">) => <button {...props} /> }));
vi.mock("@/modules/shared/ui/input", () => ({ Input: (props: ComponentPropsWithoutRef<"input">) => <input {...props} /> }));
vi.mock("@/modules/shared/ui/label", () => ({ Label: (props: ComponentPropsWithoutRef<"label">) => <label {...props} /> }));
vi.mock("@/modules/shared/ui/textarea", () => ({ Textarea: (props: ComponentPropsWithoutRef<"textarea">) => <textarea {...props} /> }));
vi.mock("./actions", () => ({ createRule: async () => ({ status: "idle" }), decideCase: async () => ({ status: "idle" }) }));

import { AntiAbusePanel } from "./anti-abuse-panel";

const caseItem = { id: "11111111-1111-4111-8111-111111111111", subject_type: "ACCOUNT", subject_hash: "a".repeat(64), risk_score: 74, event_count: 8, recommended_action: "REVIEW", status: "OPEN", row_version: 1, opened_at: "2026-09-15T10:00:00Z" };

describe("AntiAbusePanel", () => {
  it("rend l'auditeur strictement en lecture seule", () => {
    const html = renderToStaticMarkup(<AntiAbusePanel locale="fr" rules={[]} cases={[caseItem]} canMutate={false} />);
    expect(html).toContain("Vue en lecture seule");
    expect(html).not.toContain("<form");
    expect(html).not.toContain('name="decision"');
  });

  it("ne demande aucune empreinte manuelle pour une décision", () => {
    const html = renderToStaticMarkup(<AntiAbusePanel locale="fr" rules={[]} cases={[caseItem]} canMutate />);
    expect(html).toContain('name="decision"');
    expect(html).not.toContain('name="evidence"');
    expect(html).toContain("référence d’audit est générée automatiquement");
  });
});
