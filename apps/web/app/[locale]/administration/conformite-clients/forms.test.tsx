import { renderToStaticMarkup } from "react-dom/server";
import type { ComponentPropsWithoutRef } from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/components/ui/button", () => ({
  Button: ({ children, variant, ...props }: ComponentPropsWithoutRef<"button"> & { variant?: string }) => <button data-variant={variant} {...props}>{children}</button>,
}));
vi.mock("@/components/ui/label", () => ({
  Label: ({ children, ...props }: ComponentPropsWithoutRef<"label">) => <label {...props}>{children}</label>,
}));
vi.mock("@/components/ui/textarea", () => ({
  Textarea: (props: ComponentPropsWithoutRef<"textarea">) => <textarea {...props} />,
}));
vi.mock("./actions", () => ({
  createClientComplianceQuestion: async () => ({ status: "idle" }),
  decideClientCompliance: async () => ({ status: "idle" }),
  evaluateClientCompliance: async () => ({ status: "idle" }),
  reviewClientComplianceResponse: async () => ({ status: "idle" }),
}));

import { ComplianceDecisionForm } from "./decision-form";
import { getComplianceMessages } from "./messages";
import { CreateComplianceQuestionForm, EvaluateComplianceForm, ReviewComplianceResponseForm } from "./workflow-forms";

const ids = {
  complianceCaseId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
  anomalyId: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
  questionId: "ffffffff-ffff-4fff-8fff-ffffffffffff",
  idempotencyKey: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
  requestAnchor: "2026-09-11T12:00:00.000Z",
};

function controlsAndLabels(html: string) {
  const controls = [...html.matchAll(/<(?:input|select|textarea)[^>]*\sid="([^"]+)"/g)].map((match) => match[1]);
  const labels = [...html.matchAll(/<label[^>]+for="([^"]+)"/g)].map((match) => match[1]);
  return { controls, labels };
}

describe("formulaires administration conformité", () => {
  it("associe les libellés et conserve des contrôles clavier natifs", () => {
    const messages = getComplianceMessages("fr");
    const html = renderToStaticMarkup(<>
      <ComplianceDecisionForm complianceCaseId={ids.complianceCaseId} idempotencyKey={ids.idempotencyKey} locale="fr" messages={messages} />
      <CreateComplianceQuestionForm anomalyId={ids.anomalyId} idempotencyKey={ids.idempotencyKey} requestAnchor={ids.requestAnchor} locale="fr" messages={messages} />
      <EvaluateComplianceForm complianceCaseId={ids.complianceCaseId} idempotencyKey={ids.idempotencyKey} locale="fr" messages={messages} />
      <ReviewComplianceResponseForm questionId={ids.questionId} idempotencyKey={ids.idempotencyKey} locale="fr" messages={messages} />
    </>);
    const { controls, labels } = controlsAndLabels(html);
    expect(labels.length).toBeGreaterThanOrEqual(6);
    expect(labels.filter((id) => !controls.includes(id))).toEqual([]);
    expect(html).toContain('<button type="submit"');
    expect(html).toContain('type="checkbox"');
    expect(html).toContain("<select");
    expect(html).toContain("<textarea");
    expect(html).not.toContain('tabindex="-1"');
    expect((html.match(/aria-live="polite"/g) ?? []).length).toBeGreaterThanOrEqual(4);
  });

  it("rend les contenus arabes, directions explicites et reflow mobile sans largeur fixe", () => {
    const messages = getComplianceMessages("ar");
    const html = renderToStaticMarkup(
      <div dir="rtl" lang="ar">
        <CreateComplianceQuestionForm anomalyId={ids.anomalyId} idempotencyKey={ids.idempotencyKey} requestAnchor={ids.requestAnchor} locale="ar" messages={messages} />
        <ReviewComplianceResponseForm questionId={ids.questionId} idempotencyKey={ids.idempotencyKey} locale="ar" messages={messages} />
      </div>,
    );
    expect(html).toContain('dir="rtl"');
    expect(html).toContain('lang="ar"');
    expect(html).toContain('name="questionFr" dir="ltr" lang="fr"');
    expect(html).toContain('name="questionAr" dir="rtl" lang="ar"');
    expect(html).toContain("إنشاء سؤال");
    expect(html).toContain("w-full sm:w-auto");
    expect(html).toContain("sm:grid-cols-2");
    expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/);
  });
});
