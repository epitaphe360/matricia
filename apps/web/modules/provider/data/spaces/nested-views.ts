import type { ProviderNavKey } from "@/modules/provider/ui/provider-nav";

export type ProviderNestedKind =
  | "qualification"
  | "services"
  | "consultations"
  | "devis"
  | "missions"
  | "documents"
  | "facturation"
  | "reputation"
  | "planning"
  | "messages"
  | "company";

export type ProviderNestedView = {
  kind: ProviderNestedKind;
  active: ProviderNavKey;
  itemId: string | null;
  view: string | null;
  create: boolean;
};

const tools = new Set(["documents", "echanges", "revision", "apercu", "jalons", "livraison", "reglement"]);

const spaceViews: Record<string, { kind: ProviderNestedKind; active: ProviderNavKey }> = {
  qualification: { kind: "qualification", active: "qualify" },
  services: { kind: "services", active: "services" },
  consultations: { kind: "consultations", active: "consult" },
  devis: { kind: "devis", active: "quotes" },
  missions: { kind: "missions", active: "missions" },
  documents: { kind: "documents", active: "documents" },
  facturation: { kind: "facturation", active: "billing" },
  reputation: { kind: "reputation", active: "reputation" },
  planning: { kind: "planning", active: "planning" },
  messages: { kind: "messages", active: "messages" },
  notifications: { kind: "messages", active: "messages" },
  entreprise: { kind: "company", active: "company" },
};

export function resolveProviderNestedView(slug: readonly string[]): ProviderNestedView | null {
  const [head, second, third] = slug;
  if (!head) return null;
  const spec = spaceViews[head];
  if (!spec) return null;
  if (head === "notifications") {
    return { kind: "messages", active: "messages", itemId: null, view: "notifications", create: false };
  }
  if (!second) return { kind: spec.kind, active: spec.active, itemId: null, view: null, create: false };
  if (second === "nouveau" || second === "nouvelle") {
    return { kind: spec.kind, active: spec.active, itemId: null, view: null, create: true };
  }
  const view = third && tools.has(third) ? third : tools.has(second) ? second : null;
  return {
    kind: spec.kind,
    active: spec.active,
    itemId: second,
    view,
    create: false,
  };
}

export const PROVIDER_NESTED_NAV_PATHS = [
  "consultations/cr1",
  "consultations/cr1/documents",
  "consultations/cr1/echanges",
  "devis/d1",
  "devis/d1/revision",
  "devis/d1/apercu",
  "devis/nouveau",
  "missions/m1",
  "missions/m1/jalons",
  "facturation/i1",
  "documents/doc1",
  "notifications",
  "messages/cr1",
  "entreprise",
] as const;
