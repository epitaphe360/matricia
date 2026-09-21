import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));
import { FranchiseApplicationForm } from "./franchise-application-form";
import { moroccoRegions } from "@/modules/franchise/data/territories/morocco-regions";

describe("franchise application territory list", () => {
  it("propose les 12 régions du Maroc en français", () => {
    const html = renderToStaticMarkup(<FranchiseApplicationForm locale="fr" />);
    expect(html).toContain("Sélectionnez une région");
    for (const region of moroccoRegions) {
      expect(html).toContain(`value="${region.code}"`);
      expect(html).toContain(region.capitalFr);
      expect(html).toContain(region.nameFr.includes("'") ? "L&#x27;Oriental" : region.nameFr);
    }
    expect(html).not.toContain("Autre territoire");
  });

  it("propose les mêmes régions en arabe", () => {
    const html = renderToStaticMarkup(<FranchiseApplicationForm locale="ar" />);
    expect(html).toContain("سوس-ماسة (المقر: أكادير)");
    expect(html).toContain("الداخلة-وادي الذهب (المقر: الداخلة)");
  });
});
