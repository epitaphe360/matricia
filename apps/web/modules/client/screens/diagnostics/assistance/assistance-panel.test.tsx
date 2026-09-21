import type { ComponentPropsWithoutRef } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
vi.mock("@/modules/shared/ui/button", () => ({ Button: ({ children, ...props }: ComponentPropsWithoutRef<"button">) => <button {...props}>{children}</button> }));
vi.mock("./actions", () => ({ idleAssistanceAction: { status: "idle" }, runAnalysis: async () => ({ status: "idle" }), compareAnomalies: async () => ({ status: "idle" }), decideSuggestion: async () => ({ status: "idle" }) }));
import { AssistancePanel } from "./assistance-panel";
import { getAssistanceMessages } from "./messages";
import type { AssistanceDashboard } from "@/modules/shared/lib/assisted-intelligence/contracts";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
const dashboard: AssistanceDashboard = { organizations: [{ id: id(1), name: "Atlas", canAnalyze: true, canDecide: true }], model: { id: id(2), version: 1, algorithm: "TOKEN_OVERLAP_V1" }, requests: [], decisions: [], serviceCandidates: [], questionCandidates: [], anomalyCandidates: [], reassessmentCandidates: [], suggestions: [{ id: id(3), requestId: id(4), organizationId: id(1), kind: "SERVICE_CANDIDATE", targetType: "SERVICE_VERSION", targetId: id(5), relatedTargetId: null, scoreBasisPoints: 7500, explanationCode: "TOKEN_OVERLAP", modelVersion: 1, humanReviewRequired: true, evidence: { algorithm: "TOKEN_OVERLAP_V1" }, proposedPayload: {}, status: "PROPOSED", createdAt: "2026-09-12T00:00:00Z", decidedAt: null }] };
const keys = { analysis: id(6), similarity: id(7), decisions: { [id(3)]: id(8) } };

describe("AssistancePanel", () => {
  it("associe chaque contrôle visible à un libellé et expose la décision humaine", () => {
    const html = renderToStaticMarkup(<AssistancePanel dashboard={dashboard} locale="fr" messages={getAssistanceMessages("fr")} keys={keys}/>);
    const controls = [...html.matchAll(/<(?:input|select|textarea)[^>]*\sid="([^"]+)"/g)].map((match) => match[1]);
    const labels = [...html.matchAll(/<label[^>]+for="([^"]+)"/g)].map((match) => match[1]);
    expect(labels.filter((label) => !controls.includes(label))).toEqual([]);
    expect(html).toContain("Décision humaine obligatoire");
    expect(html).toContain("Décision humaine obligatoire");
  });

  it("rend l’arabe RTL sans largeur fixe incompatible avec 360 px", () => {
    const html = renderToStaticMarkup(<div dir="rtl" lang="ar"><AssistancePanel dashboard={dashboard} locale="ar" messages={getAssistanceMessages("ar")} keys={keys}/></div>);
    expect(html).toContain('dir="rtl"');
    expect(html).toContain("قرار بشري إلزامي");
    expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/u);
    expect(html).toContain("min-h-11");
  });
});
