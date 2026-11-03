import { describe, expect, it } from "vitest";
import { z } from "zod";
import { namespacedCommandUuid, type CommandUuidNamespace } from "./namespaced-command-uuid";
const names: CommandUuidNamespace[]=["service-impact","service-submit","questionnaire-publish","service-duplicate","service-archive","questionnaire-clone","subcategory-create","category-submit","subcategory-submit"];
describe("namespaced native command UUID",()=>{
 it.each(["8d037500-0000-4000-8000-000000000000","8d037500-0000-4000-b000-ffffffffffff","8d037500-0000-7000-a000-000000000001"])("preserves strict UUID version and variant for %s",seed=>{
  const keys=names.map(name=>namespacedCommandUuid(seed,name));
  expect(new Set([seed,...keys]).size).toBe(names.length+1);
  for(const key of keys){expect(z.string().uuid().safeParse(key).success).toBe(true);expect(key[14]).toBe(seed[14]);expect(key[19]).toBe(seed[19]);}
 });
 it("is deterministic across hydration, retries and differently cased seed",()=>{const seed="8D037500-0000-4000-8000-000000000001";for(const name of names)expect(namespacedCommandUuid(seed,name)).toBe(namespacedCommandUuid(seed.toLowerCase(),name));});
 it("rejects malformed source identities without weakening form validation",()=>{expect(()=>namespacedCommandUuid("8d037500-0000-a000-8000-000000000001","service-submit")).toThrow();});
});
