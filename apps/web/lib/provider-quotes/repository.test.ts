import { describe, expect, it, vi } from "vitest";
vi.mock("@/lib/supabase/server", () => ({ getSupabaseServerClient: vi.fn() }));
import { parseQuoteVersionAmounts, unambiguousTaxRules } from "./repository";

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

describe("provider quote exact amount projection", () => {
  const projected = { id:"11111111-1111-4111-8111-111111111111",version_number:1,currency:"MAD",subtotal_minor:"900719925474099300",tax_minor:"180143985094819860",total_minor:"1080863910568919160" };
  it("conserve les bigint projetés en texte au-delà de Number.MAX_SAFE_INTEGER",()=>expect(parseQuoteVersionAmounts([projected]).data?.[0]?.subtotal_minor).toBe("900719925474099300"));
  it("refuse une réponse PostgREST numérique susceptible de perdre la précision",()=>expect(parseQuoteVersionAmounts([{...projected,subtotal_minor:900719925474099300}]).success).toBe(false));
});
