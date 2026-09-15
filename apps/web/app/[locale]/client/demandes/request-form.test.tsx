import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
vi.mock("./actions", () => ({ createRequestAction: vi.fn() }));
vi.mock("@/components/ui/button", () => ({ Button: (props: React.ButtonHTMLAttributes<HTMLButtonElement>) => <button {...props} /> }));
vi.mock("@/components/ui/input", () => ({ Input: (props: React.InputHTMLAttributes<HTMLInputElement>) => <input {...props} /> }));
vi.mock("@/components/ui/textarea", () => ({ Textarea: (props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) => <textarea {...props} /> }));
import { RequestForm } from "./request-form";
import { getClientRfqMessages } from "./messages";

describe("guided client request form", () => {
  it("contains only business fields and preserves the confirmed priority", () => {
    const html = renderToStaticMarkup(<RequestForm locale="fr" messages={getClientRfqMessages("fr")} context={{ opportunityId: "11111111-1111-4111-8111-111111111111", organizationId: "22222222-2222-4222-8222-222222222222", organizationName: "Entreprise Test", serviceName: "Sécuriser les accès", title: "Accès à renforcer", description: "Renforcer les accès sensibles de l’entreprise." }} />);
    for (const field of ["libraryId", "serviceId", "questionnaireVersionId", "catalogSnapshotHash", "questionnaireSnapshotHash", "idempotencyKey", "changeReason"]) expect(html).not.toContain(`name="${field}"`);
    expect(html).toContain('name="opportunityId"'); expect(html).toContain("Entreprise Test"); expect(html).toContain("Enregistrer le brouillon");
  });
});
