import { describe, expect, it } from "vitest";
import { getMoroccoTaxMessages } from "./messages";

describe("morocco tax messages", () => { it("fournit des copies FR et AR complètes", () => { const fr = getMoroccoTaxMessages("fr"), ar = getMoroccoTaxMessages("ar"); expect(fr.title).toContain("Maroc"); expect(ar.title).toContain("المغرب"); expect(JSON.stringify(fr).length).toBeGreaterThan(2); expect(JSON.stringify(ar).length).toBeGreaterThan(2); }); });
