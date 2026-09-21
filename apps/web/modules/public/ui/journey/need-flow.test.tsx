import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { NeedFlow, needProgressPercent, parseNeedDraft } from "./need-flow";
import { canonicalizePublicNeedClassification } from "@/modules/public/data/need-intent/model";

describe("NeedFlow continuity", () => {
  it("renders an accessible loading heading in both directions", () => {
    expect(renderToStaticMarkup(<NeedFlow locale="fr" />)).toContain("<h1>Décrivez votre besoin</h1>");
    expect(renderToStaticMarkup(<NeedFlow locale="ar" />)).toContain('dir="rtl"');
  });

  it("exposes a real stage progress bar, not a decorative strip", () => {
    expect(needProgressPercent(1, 5)).toBe(20);
    expect(needProgressPercent(5, 5)).toBe(100);
    const html = renderToStaticMarkup(<NeedFlow locale="fr" />);
    expect(html).toContain('role="progressbar"');
    expect(html).toContain('aria-valuenow="1"');
    expect(html).toContain('aria-valuemax="5"');
  });

  it("migrates a valid v2 draft without inventing confirmation", () => {
    const future = Date.now() + 10_000;
    const result = parseNeedDraft(JSON.stringify({ version: 2, step: 4, need: "Audit du réseau interne", location: "", timing: "", constraints: "", expiresAt: future }), "fr");
    expect(result.status).toBe("valid");
    expect(result.draft).toMatchObject({ version: 3, step: 4, confirmed: false, answers: {} });
  });

  it("rejects expired drafts and preserves canonical codes", () => {
    const classification = canonicalizePublicNeedClassification({ libraryCode: "IT", serviceCode: "IT-AUDIT-SI" }, "fr");
    expect(parseNeedDraft(JSON.stringify({ version: 3, step: 2, need: "Audit du réseau interne", location: "", timing: "", constraints: "", classification, confirmed: true, expiresAt: 1 }), "fr", "", classification, 2).status).toBe("expired");
    const valid = parseNeedDraft(JSON.stringify({ version: 3, step: 2, need: "Audit du réseau interne", location: "", timing: "", constraints: "", classification, confirmed: true, expiresAt: 20 }), "fr", "", null, 2);
    expect(valid.draft?.classification?.serviceCode).toBe("IT-AUDIT-SI");
  });

  it("plafonne le récapitulatif à l’étape 4", () => {
    const future = Date.now() + 10_000;
    const result = parseNeedDraft(JSON.stringify({ version: 3, step: 9, need: "Audit du réseau interne", location: "", timing: "", constraints: "", expiresAt: future }), "fr");
    expect(result.draft?.step).toBe(4);
  });

  it("restores confirmed answers without inventing a service", () => {
    const future = Date.now() + 10_000;
    const result = parseNeedDraft(JSON.stringify({ version: 3, step: 2, need: "Audit du réseau interne", location: "Casablanca", timing: "", constraints: "", answers: { "site.count": "3" }, expiresAt: future }), "fr");
    expect(result.draft?.answers).toEqual({ "site.count": "3" });
    expect(result.draft?.classification).toBeNull();
  });
});
