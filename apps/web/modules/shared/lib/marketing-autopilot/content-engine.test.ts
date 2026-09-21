import { describe, expect, it } from "vitest";
import { generateServiceContent } from "./content-engine";

const input = { campaignId:"11111111-1111-4111-8111-111111111111",serviceId:"22222222-2222-4222-8222-222222222222",libraryId:"33333333-3333-4333-8333-333333333333",organizationId:"44444444-4444-4444-8444-444444444444",language:"FR" as const,serviceName:"Sauvegarde gérée",valueProposition:"Protégez les données essentielles avec une stratégie vérifiable.",primaryCta:"Lancer le diagnostic",trackedUrl:"https://matricia.example/diagnostic",approvedHashtags:["#Matricia","#Sauvegarde"],templateKey:"PROBLEM_SOLUTION" as const,sourceHash:"a".repeat(64)};

describe("deterministic marketing content engine",()=>{
  it("produces exactly LinkedIn, Facebook and a 25-second Reel",()=>{
    const result=generateServiceContent(input);
    expect(result.map((value)=>value.channel)).toEqual(["LINKEDIN","FACEBOOK","REEL"]);
    expect(result[2]?.durationSeconds).toBe(25);
  });
  it("is deterministic and emits normalized traceable CTA parameters",()=>{
    expect(generateServiceContent(input)).toEqual(generateServiceContent(input));
    const url=new URL(generateServiceContent(input)[0]!.landingUrl);
    expect(Object.fromEntries(url.searchParams)).toMatchObject({campaign_id:input.campaignId,library_id:input.libraryId,service_id:input.serviceId,utm_medium:"social",utm_source:"linkedin"});
  });
  it("emits native Arabic copy without changing the structured contract",()=>{
    const result=generateServiceContent({...input,language:"AR",serviceName:"النسخ الاحتياطي",valueProposition:"حماية البيانات الأساسية بمسار موثق."});
    expect(result).toHaveLength(3); expect(result[0]?.hook).toMatch(/[\u0600-\u06ff]/u); expect(result.every((item)=>item.contentHash.length===64)).toBe(true);
  });
  it("fails closed on personal data, absolute promises and unsourced numbers",()=>{
    expect(()=>generateServiceContent({...input,valueProposition:"Contact client@example.com"})).toThrow("MARKETING_PRIVACY_CHECK_FAILED");
    expect(()=>generateServiceContent({...input,valueProposition:"Résultat garanti"})).toThrow("MARKETING_CLAIMS_CHECK_FAILED");
    expect(()=>generateServiceContent({...input,valueProposition:"Amélioration de 42 points"})).toThrow("MARKETING_SOURCE_CHECK_FAILED");
  });
  it("applies six distinct template narratives",()=>{
    const keys=["PROBLEM_SOLUTION","EXPERT_TIP","PROVIDER_INTRO","BEFORE_AFTER","SERVICE_OF_MONTH","SUCCESS_CASE"] as const;
    const hooks=keys.map(templateKey=>generateServiceContent({...input,templateKey})[0]!.hook);
    expect(new Set(hooks).size).toBe(6);
  });
  it("renders authoritative minor units exactly in French and Arabic",()=>{
    const offer={quoteVersionId:"55555555-5555-4555-8555-555555555555",totalMinor:"120000",currency:"MAD"};
    expect(generateServiceContent({...input,offer})[0]?.body).toContain("1 200,00 MAD");
    expect(generateServiceContent({...input,language:"AR",serviceName:"النسخ الاحتياطي",valueProposition:"حماية البيانات الأساسية بمسار موثق.",offer})[0]?.body).toContain("١٬٢٠٠٫٠٠ MAD");
  });
});
