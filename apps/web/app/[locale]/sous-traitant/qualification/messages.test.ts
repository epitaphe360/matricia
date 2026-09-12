import { describe,expect,it } from "vitest";
import { getProviderMessages } from "./messages";
describe("provider qualification localization",()=>{
 it("has complete FR and Arabic copies",()=>{const fr=getProviderMessages("fr");const ar=getProviderMessages("ar");expect(Object.keys(ar)).toEqual(Object.keys(fr));expect(ar.title).toMatch(/[\u0600-\u06ff]/u);expect(fr.description.length).toBeGreaterThan(30)});
 it("expose uniquement des copies renseignées",()=>{for(const locale of["fr","ar"]as const)for(const value of Object.values(getProviderMessages(locale)))expect(value.trim().length).toBeGreaterThan(0)});
});
