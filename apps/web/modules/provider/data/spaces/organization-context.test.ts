import {describe,it,expect} from "vitest";
import {selectProviderMembership} from "./organization-context";
const a={organization_id:"11111111-1111-4111-8111-111111111111"},b={organization_id:"22222222-2222-4222-8222-222222222222"};
describe("provider tenant selection",()=>{
 it("requires explicit selection for multiple authorized organizations",()=>{expect(selectProviderMembership([a,b])).toBeUndefined();expect(selectProviderMembership([a,b],b.organization_id)).toBe(b);});
 it("never falls back to another tenant for forged or malformed scope",()=>{expect(selectProviderMembership([a],b.organization_id)).toBeUndefined();expect(selectProviderMembership([a],"../other")).toBeUndefined();});
 it("allows the sole authorized organization and deduplicates memberships",()=>{expect(selectProviderMembership([a,a])).toBe(a);expect(selectProviderMembership([])).toBeUndefined();});
});
