import { describe, expect, it } from "vitest";
import { adminActorLinks, adminParcoursLinks, ADMIN_SPACE_IDS } from "@/modules/admin/data/spaces/admin-nav";
import { spaceSpec } from "@/modules/admin/data/spaces/screen-catalog";

describe("catalogue admin Figma", () => {
  it("sépare chaque entrée Acteurs et Parcours vers une route unique", () => {
    const actors = adminActorLinks("fr", "");
    const parcours = adminParcoursLinks("fr", "");
    const hrefs = [...actors, ...parcours].map((item) => item.href);
    expect(new Set(hrefs).size).toBe(hrefs.length);
    expect(actors.find((item) => item.id === "qualification")?.href).toContain("/administration/qualification");
    expect(parcours.find((item) => item.id === "diagnostics")?.href).toContain("/administration/diagnostics");
    expect(parcours.find((item) => item.id === "litiges")?.href).toContain("/administration/litiges");
  });

  it("n’emploie pas d’exemple illustratif dans les libellés", () => {
    for (const id of ADMIN_SPACE_IDS) {
      const spec = spaceSpec(id);
      const blob = [
        spec.title("fr"), spec.lead("fr"), spec.empty("fr"),
        spec.columns("fr").join(" "), spec.pills("fr").join(" "),
        spec.title("ar"), spec.lead("ar"),
      ].join(" ");
      expect(blob.toLowerCase()).not.toContain("exemple illustratif");
    }
  });
});
