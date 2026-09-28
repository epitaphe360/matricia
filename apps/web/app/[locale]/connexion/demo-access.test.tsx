import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("./demo-actions", () => ({ connectDemoPersona: async () => undefined }));

import { DemoAccess } from "./demo-access";

describe("DemoAccess", () => {
  it("expose les quatre personas de démonstration en français", () => {
    const html = renderToStaticMarkup(<DemoAccess locale="fr" />);
    expect(html).toContain("Connexion automatique");
    expect(html).toContain("Client");
    expect(html).toContain("Sous-traitant");
    expect(html).toContain("Franchisé");
    expect(html).toContain("Admin");
    expect(html).toContain('value="franchise"');
    expect(html).toContain('value="admin"');
  });

  it("expose les quatre personas de démonstration en arabe", () => {
    const html = renderToStaticMarkup(<DemoAccess locale="ar" />);
    expect(html).toContain("دخول تلقائي");
    expect(html).toContain("مقاول من الباطن");
    expect(html).toContain("صاحب امتياز");
    expect(html).toContain('value="franchise"');
    expect(html).toContain('value="admin"');
  });
});
