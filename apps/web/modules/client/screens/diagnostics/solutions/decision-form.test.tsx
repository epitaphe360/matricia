import { renderToStaticMarkup } from "react-dom/server";
import type { ComponentPropsWithoutRef } from "react";
import { describe, expect, it, vi } from "vitest";
vi.mock("@/modules/shared/ui/button", () => ({ Button: ({ children, ...props }: ComponentPropsWithoutRef<"button">) => <button {...props}>{children}</button> }));
vi.mock("./actions", () => ({ decideAction: async () => ({ status: "idle" }), idle: { status: "idle" } }));
import { DecisionForm } from "./decision-form";
import { messages } from "./messages";
describe("DecisionForm", () => {
  it("associe chaque champ à un libellé et reste fluide à 360 px", () => { const html = renderToStaticMarkup(<DecisionForm locale="fr" solutionSetId="11111111-1111-4111-8111-111111111111" level="ESSENTIAL" idempotencyKey="command-123" m={messages("fr")} />); const ids = [...html.matchAll(/<(?:select|textarea|input)[^>]*id="([^"]+)"/g)].map((match) => match[1]); const labels = [...html.matchAll(/<label[^>]*for="([^"]+)"/g)].map((match) => match[1]); expect(labels.every((label) => ids.includes(label))).toBe(true); expect(html).toContain('aria-busy="false"'); expect(html).toContain("w-full sm:w-auto"); expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/u); });
  it("rend les libellés arabes", () => { const html = renderToStaticMarkup(<div dir="rtl"><DecisionForm locale="ar" solutionSetId="11111111-1111-4111-8111-111111111111" level="STANDARD" idempotencyKey="command-123" m={messages("ar")} /></div>); expect(html).toContain("سبب القرار"); expect(html).toContain('dir="rtl"'); });
});
