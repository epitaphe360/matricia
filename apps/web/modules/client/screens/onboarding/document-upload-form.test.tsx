import { renderToStaticMarkup } from "react-dom/server";
import type { ComponentPropsWithoutRef } from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@/modules/shared/ui/button", () => ({
  Button: ({ children, ...props }: ComponentPropsWithoutRef<"button">) => <button {...props}>{children}</button>,
}));
vi.mock("@/modules/shared/ui/input", () => ({
  Input: (props: ComponentPropsWithoutRef<"input">) => <input {...props} />,
}));
vi.mock("@/modules/shared/ui/label", () => ({
  Label: ({ children, ...props }: ComponentPropsWithoutRef<"label">) => <label {...props}>{children}</label>,
}));
vi.mock("./actions", () => ({
  uploadClientComplianceDocument: async () => ({ status: "idle" }),
}));

import { ClientDocumentUploadForm } from "./document-upload-form";
import { getClientOnboardingMessages } from "./messages";

const props = {
  complianceCaseId: "44444444-4444-4444-8444-444444444444",
  idempotencyKey: "66666666-6666-4666-8666-666666666666",
} as const;

describe("ClientDocumentUploadForm", () => {
  it("rend des contrôles nommés, bornés et associés à leurs libellés", () => {
    const html = renderToStaticMarkup(
      <ClientDocumentUploadForm {...props} locale="fr" messages={getClientOnboardingMessages("fr")} />,
    );
    expect(html).toContain('name="documentNumber"');
    expect(html).toContain('minLength="2"');
    expect(html).toContain('maxLength="120"');
    expect(html).toContain('name="file"');
    expect(html).toContain('accept="application/pdf,image/jpeg,image/png"');
    expect(html).toContain('aria-live="polite"');
    const inputIds = [...html.matchAll(/<(?:input|select)[^>]*\sid="([^"]+)"/g)].map((match) => match[1]);
    const labelTargets = [...html.matchAll(/<label[^>]+for="([^"]+)"/g)].map((match) => match[1]);
    expect(inputIds.length).toBeGreaterThanOrEqual(6);
    expect(labelTargets.length).toBeGreaterThanOrEqual(6);
    expect(labelTargets.filter((id) => !inputIds.includes(id))).toEqual([]);
  });

  it("conserve le contenu arabe, le RTL hérité et un reflow sans largeur fixe à 360 px", () => {
    const html = renderToStaticMarkup(
      <div dir="rtl" lang="ar">
        <ClientDocumentUploadForm {...props} locale="ar" messages={getClientOnboardingMessages("ar")} />
      </div>,
    );
    expect(html).toContain('dir="rtl"');
    expect(html).toContain('lang="ar"');
    expect(html).toContain("رفع المستند");
    expect(html).toContain("w-full sm:w-auto");
    expect(html).toContain("grid gap-4 sm:grid-cols-2");
    expect(html).not.toMatch(/(?:min-w|max-w|w)-\[(?:[4-9]\d\d|\d{4,})px\]/);
  });
});
