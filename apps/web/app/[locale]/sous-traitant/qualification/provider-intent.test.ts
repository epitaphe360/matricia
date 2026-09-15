import { describe,expect,it,vi } from "vitest";
import { clearProviderIntent,readProviderIntent } from "./provider-intent";

describe("provider public intent handoff",()=>{
  it("prefers the stable key and bounds its size",()=>{const storage={getItem:vi.fn((key:string)=>key==="matricia.provider-intent"?"x".repeat(2100):"legacy")};expect(readProviderIntent(storage,"fr")).toHaveLength(2000)});
  it("supports the localized legacy key",()=>{const storage={getItem:vi.fn((key:string)=>key.endsWith(".ar")?"خدمات محاسبية":null)};expect(readProviderIntent(storage,"ar")).toBe("خدمات محاسبية")});
  it("clears both keys only when explicitly called after confirmation",()=>{const removeItem=vi.fn();expect(clearProviderIntent({removeItem},"fr")).toBe(true);expect(removeItem.mock.calls.map(([key])=>key)).toEqual(["matricia.provider-intent","matricia.provider-intent.fr"])});
  it("fails safely when browser storage is blocked",()=>{expect(readProviderIntent({getItem(){throw new Error("blocked")}},"fr")).toBe("");expect(clearProviderIntent({removeItem(){throw new Error("blocked")}},"fr")).toBe(false)});
});
