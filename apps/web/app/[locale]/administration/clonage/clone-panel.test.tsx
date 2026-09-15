import type { ComponentPropsWithoutRef } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
vi.mock("@/components/ui/button", () => ({ Button: (props: ComponentPropsWithoutRef<"button">) => <button {...props}/> }));
vi.mock("@/components/ui/input", () => ({ Input: (props: ComponentPropsWithoutRef<"input">) => <input {...props}/> }));
vi.mock("@/components/ui/card", () => ({ Card: (p: ComponentPropsWithoutRef<"div">) => <div {...p}/>, CardContent: (p: ComponentPropsWithoutRef<"div">) => <div {...p}/>, CardHeader: (p: ComponentPropsWithoutRef<"div">) => <div {...p}/>, CardTitle: (p: ComponentPropsWithoutRef<"h2">) => <h2 {...p}/> }));
vi.mock("./actions", () => ({ cloneChecklist: async () => ({ status: "idle" }), cloneClauses: async () => ({ status: "idle" }), cloneQuestionnaire: async () => ({ status: "idle" }) }));
import { ClonePanel, type CloneChoices } from "./clone-panel";
const id = "11111111-1111-4111-8111-111111111111";
const choices: CloneChoices = { questionnaires: [{ value: id, label: "Diagnostic · v1", scope: id }], releases: [{ value: id, label: "Release brouillon", scope: id }], contracts: [{ value: id, label: "Contrat 1234 · v1" }], clauseSets: [], checklists: [{ value: id, label: "Checklist audit" }], services: [{ value: id, label: "Audit numérique" }], organizations: [{ value: id, label: "Matricia" }] };
describe("ClonePanel", () => {
  it("remplace les identifiants techniques par des sélections métier", () => { const html = renderToStaticMarkup(<ClonePanel locale="fr" keys={[id,id,id]} choices={choices} canMutate/>); expect(html).toContain("Diagnostic · v1"); expect(html).toContain("Matricia"); expect(html).not.toContain("UUID"); expect(html).not.toContain('name="sourceId" required="" dir="ltr"'); });
  it("ne rend aucune commande pour un auditeur", () => { const html = renderToStaticMarkup(<ClonePanel locale="fr" keys={[id,id,id]} choices={choices} canMutate={false}/>); expect(html).toContain("lecture seule"); expect(html).not.toContain("<form"); });
});
