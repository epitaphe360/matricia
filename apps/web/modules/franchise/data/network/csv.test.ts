import { describe, expect, it } from "vitest";
import { parseFranchiseProviderCsv } from "./csv";

describe("parseFranchiseProviderCsv", () => {
  it("lit un fichier avec en-tête franco-arabe", () => {
    const parsed = parseFranchiseProviderCsv("nom,courriel,organisation\nStudio Atlas,atlas@example.invalid,Atlas\nConseil Anfa,anfa@example.invalid,");
    expect(parsed.status).toBe("ok");
    if (parsed.status !== "ok") return;
    expect(parsed.rows).toHaveLength(2);
    expect(parsed.rows[0]).toEqual({ displayName: "Studio Atlas", contactEmail: "atlas@example.invalid", organizationName: "Atlas" });
  });

  it("refuse plus de 50 lignes et un courriel invalide", () => {
    expect(parseFranchiseProviderCsv("a,not-an-email,org").status).toBe("error");
    const lines = Array.from({ length: 51 }, (_, index) => `Nom ${index},user${index}@example.invalid,Org`);
    expect(parseFranchiseProviderCsv(lines.join("\n")).status).toBe("error");
  });
});
