import { describe, expect, it, vi } from "vitest";
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: vi.fn() }));
import { unambiguousTaxRules } from "./repository";

const rule = (id: string, category: string, rate: number) => ({
  id,
  category_code: category,
  rate_basis_points: rate,
  effective_from: "2026-01-01",
  effective_to: null,
  professional_validation_status: "VALIDATED" as const,
});

describe("provider quote tax selection", () => {
  it("exclut toute catégorie fiscale ambiguë", () => {
    const selected = unambiguousTaxRules([
      rule("11111111-1111-4111-8111-111111111111", "STANDARD_SERVICE", 2000),
      rule("22222222-2222-4222-8222-222222222222", "STANDARD_SERVICE", 1000),
      rule("33333333-3333-4333-8333-333333333333", "EXEMPT", 0),
    ]);
    expect(selected.map((item) => item.category_code)).toEqual(["EXEMPT"]);
  });
  it("conserve les versions non chevauchantes nécessaires aux dates futures",()=>{const selected=unambiguousTaxRules([{...rule("11111111-1111-4111-8111-111111111111","STANDARD_SERVICE",2000),effective_to:"2026-12-31"},{...rule("22222222-2222-4222-8222-222222222222","STANDARD_SERVICE",2100),effective_from:"2027-01-01"}]);expect(selected.map(item=>item.id)).toHaveLength(2);});
});
