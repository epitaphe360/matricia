import { describe, expect, it } from "vitest";
import { getMoroccoTaxMessages } from "./messages";

describe("morocco tax messages", () => { it("fournit FR et AR sans placeholder", () => { const fr = getMoroccoTaxMessages("fr"), ar = getMoroccoTaxMessages("ar"); expect(fr.title).toContain("Maroc"); expect(ar.title).toContain("المغرب"); expect(JSON.stringify({ fr, ar })).not.toMatch(/TODO|FIXME|TBD/); }); });
