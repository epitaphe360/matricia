import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { Question } from "../../../../lib/questionnaire-sessions/model";

vi.mock("../../../../components/ui/button", () => ({ Button: (props: React.ComponentProps<"button">) => <button {...props} /> }));
vi.mock("../../../../components/ui/input", () => ({ Input: (props: React.ComponentProps<"input">) => <input {...props} /> }));
vi.mock("../../../../components/ui/label", () => ({ Label: (props: React.ComponentProps<"label">) => <label {...props} /> }));

import { getQuestionnaireMessages } from "./messages";
import { StructuredQuestionControl } from "./structured-controls";

const id = (n: number) => String(n).padStart(8, "0") + "-0000-4000-8000-000000000000";
const base = (type: Question["type"], value: unknown = null): Question => ({ id: id(10), sectionId: id(11), sortOrder: 1, labelFr: "Question", labelAr: "سؤال", helpFr: null, helpAr: null, whyFr: null, whyAr: null, type, required: true, nullable: false, options: [], validation: {}, structured: null, answer: value === null ? null : { value, rowVersion: 1, answeredAt: "2026-09-13T00:00:00Z", expiresAt: null, requiresRevalidation: false } });
const documents = [{ id: id(1), organizationId: id(2), name: "preuve.png", type: "TAX_DOCUMENT" as const, mimeType: "image/png", status: "VERIFIED" as const }];

describe("StructuredQuestionControl", () => {
  it("uses private document choices instead of free text for FILE, IMAGE and MULTI_FILE", () => {
    for (const type of ["FILE", "IMAGE", "MULTI_FILE"] as const) {
      const html = renderToStaticMarkup(<StructuredQuestionControl question={base(type)} documents={documents} messages={getQuestionnaireMessages("fr")} describedBy="help error" />);
      expect(html).toContain("preuve.png");
      if (type !== "MULTI_FILE") expect(html).toContain(id(1));
      expect(html).not.toContain("<textarea");
      expect(html).not.toContain("JSON");
    }
  });
  it("renders schema-driven TABLE fields with published bounds and exact-number constraints", () => {
    const question = { ...base("TABLE"), validation: { minItems: 1, maxItems: 3 }, structured: { kind: "TABLE", version: "1", minRows: 1, maxRows: 3, columns: [{ key: "quantity", type: "INTEGER", nullable: false, options: [], numeric: {}, validation: { minimum: "1", maximum: "99" } }] } };
    const html = renderToStaticMarkup(<StructuredQuestionControl question={question} documents={documents} messages={getQuestionnaireMessages("fr")} describedBy="help error" />);
    expect(html).toContain("quantity");
    expect(html).toContain('min="1"');
    expect(html).toContain('max="99"');
    expect(html).toContain("Minimum 1, maximum 3");
    expect(html).not.toContain("<textarea");
  });
  it("serializes nested MONEY, DATE_RANGE, TIME and CURRENCY with database-compatible tagged values", () => {
    const fields = ["MONEY", "DATE_RANGE", "TIME", "CURRENCY"].map((type, index) => ({ key: ["price", "period", "meeting", "currency"][index], type, nullable: false, options: [], numeric: {}, validation: {} }));
    const value = [{ price: { kind: "MONEY", amountMinor: "12500", currency: "MAD" }, period: { kind: "DATE_RANGE", start: "2026-09-12", end: "2026-09-20" }, meeting: { kind: "LOCAL_TIME", localDate: "2026-09-12", localTime: "09:30", timeZone: "Africa/Casablanca", dstPolicy: "REJECT" }, currency: "MAD" }];
    const question = { ...base("TABLE", value), structured: { kind: "TABLE", version: "1", minRows: 1, maxRows: 2, columns: fields } };
    const html = renderToStaticMarkup(<StructuredQuestionControl question={question} documents={documents} messages={getQuestionnaireMessages("fr")} />);
    expect(html).toContain("&quot;kind&quot;:&quot;MONEY&quot;");
    expect(html).toContain("&quot;amountMinor&quot;:&quot;12500&quot;");
    expect(html).toContain("&quot;kind&quot;:&quot;DATE_RANGE&quot;");
    expect(html).toContain("&quot;kind&quot;:&quot;LOCAL_TIME&quot;");
    expect(html).toContain("&quot;currency&quot;:&quot;MAD&quot;");
    expect(html).not.toContain("<textarea");
  });
  it("renders accessible builders for every remaining structured V1 type", () => {
    for (const type of ["REPEATER", "CONTACT", "ORGANIZATION", "PRODUCT_LIST", "SITE_LIST", "MILESTONE_LIST", "BUDGET_BREAKDOWN"] as const) {
      const question = type === "REPEATER" ? { ...base(type), structured: { kind: "REPEATER", version: "1", minItems: 1, maxItems: 2, children: [{ key: "name", type: "SHORT_TEXT", nullable: false, options: [], numeric: {}, validation: { minLength: 2 } }] } } : base(type);
      const html = renderToStaticMarkup(<StructuredQuestionControl question={question} documents={documents} messages={getQuestionnaireMessages("ar")} describedBy="help error" />);
      expect(html).toContain('name="answerValue"');
      expect(html).not.toContain("<textarea");
      expect(html).not.toContain("JSON");
    }
  });
});
