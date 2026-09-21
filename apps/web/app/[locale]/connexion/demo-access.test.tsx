import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("./demo-actions", () => ({ connectDemoPersona: async () => undefined }));

import { DemoAccess } from "./demo-access";

describe("DemoAccess", () => {
  it("expose les quatre personas de démonstration en français", () => {
    const html = renderToStaticMarkup(<DemoAccess locale="fr" />);
    expect(html).toContain("Voir le tableau de bord Client");
    expect(html).toContain("Voir le tableau de bord Prestataire");
    expect(html).toContain("Voir l’espace Franchisé");
    expect(html).toContain("Voir le tableau de bord Admin");
    expect(html).toContain('value="franchise"');
    expect(html).toContain('value="admin"');
  });

  it("expose les quatre personas de démonstration en arabe", () => {
    const html = renderToStaticMarkup(<DemoAccess locale="ar" />);
    expect(html).toContain("عرض فضاء صاحب الامتياز");
    expect(html).toContain("عرض لوحة تحكم الإدارة");
    expect(html).toContain('value="franchise"');
    expect(html).toContain('value="admin"');
  });
});
