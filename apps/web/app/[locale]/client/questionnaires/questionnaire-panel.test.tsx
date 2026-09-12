import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { QuestionnaireDashboard } from "@/lib/questionnaire-sessions/model";
vi.mock("./actions", () => ({ saveQuestionnaireAnswerAction: vi.fn(), startQuestionnaireAction: vi.fn(), submitQuestionnaireAction: vi.fn() }));
vi.mock("../../../../components/ui/badge", () => ({ Badge: (props: React.ComponentProps<"span">) => <span {...props} /> }));
vi.mock("../../../../components/ui/button", () => ({ Button: (props: React.ComponentProps<"button">) => <button {...props} /> }));
vi.mock("../../../../components/ui/input", () => ({ Input: (props: React.ComponentProps<"input">) => <input {...props} /> }));
vi.mock("../../../../components/ui/label", () => ({ Label: (props: React.ComponentProps<"label">) => <label {...props} /> }));
vi.mock("../../../../components/ui/textarea", () => ({ Textarea: (props: React.ComponentProps<"textarea">) => <textarea {...props} /> }));
import { getQuestionnaireMessages } from "./messages";
import { QuestionnairePanel } from "./questionnaire-panel";

const id = (n: number) => `${String(n).padStart(8, "0")}-0000-4000-8000-000000000000`;
const dashboard: QuestionnaireDashboard = { organizations: [{ id: id(1), name: "Atlas" }], questionnaires: [{ id: id(2), version: 1, titleFr: "Diagnostic", titleAr: "التشخيص", descriptionFr: "Diagnostic client", descriptionAr: "تشخيص العميل" }], sessions: [], selected: { id: id(3), organizationId: id(1), questionnaireVersionId: id(2), status: "IN_PROGRESS", locale: "ar-MA", updatedAt: "2026-09-12T12:00:00Z", submittedAt: null, rowVersion: 2, titleFr: "Diagnostic", titleAr: "التشخيص", descriptionFr: "Diagnostic client", descriptionAr: "تشخيص العميل", answeredCount: 0, questionCount: 1, sections: [{ id: id(4), labelFr: "Contexte", labelAr: "السياق", helpFr: null, helpAr: null, sortOrder: 1, questions: [{ id: id(5), sectionId: id(4), sortOrder: 1, labelFr: "Budget", labelAr: "الميزانية", helpFr: null, helpAr: null, whyFr: null, whyAr: null, type: "MONEY", required: true, nullable: false, options: [], validation: {}, structured: null, answer: null }] }] } };
const identity = { idempotencyKey: "command-123", correlationId: id(8) };
describe("QuestionnairePanel", () => { it("renders Arabic controls with labels and responsive widths", () => { const html = renderToStaticMarkup(<div dir="rtl"><QuestionnairePanel locale="ar" dashboard={dashboard} messages={getQuestionnaireMessages("ar")} identities={{ start: identity, submit: identity, answers: { [id(5)]: identity } }} /></div>); const controls = [...html.matchAll(/<(?:input|select|textarea)[^>]*\sid="([^"]+)"/g)].map((match) => match[1]), labels = [...html.matchAll(/<label[^>]*\sfor="([^"]+)"/g)].map((match) => match[1]); expect(controls.length).toBeGreaterThanOrEqual(4); expect(labels).toEqual(expect.arrayContaining(controls)); expect(html).toContain("الميزانية"); expect(html).toContain("min-h-11"); expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/u); }); });
