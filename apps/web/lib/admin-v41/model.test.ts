import { describe,expect,it } from "vitest";
import { adminV41Modules,adminV41OverviewSchema,externalValidationDashboardSchema,externalValidationDecisionInput,externalValidationKinds,externalValidationSubmitInput } from "./model";

describe("admin V4.1 overview",()=>{
 it("requires every bounded operational module and three separated flows",()=>{
  const modules=adminV41Modules.map(key=>({key,open:0,exceptions:0}));
  expect(adminV41OverviewSchema.parse({generated_at:"2026-09-13T10:00:00.000Z",limit:50,financial_flows:{client_to_provider_declared:1,matricia_own_revenue:2,provider_commission_receipts:3},modules}).modules).toHaveLength(13);
 });
 it("rejects negative or partial projections",()=>{
  expect(adminV41OverviewSchema.safeParse({generated_at:"2026-09-13T10:00:00.000Z",limit:50,financial_flows:{client_to_provider_declared:-1,matricia_own_revenue:0,provider_commission_receipts:0},modules:[]}).success).toBe(false);
 });
 it("accepts the complete external readiness checklist and guarded commands",()=>{
  const checklist=externalValidationKinds.map(kind=>({kind,approved:false}));
  expect(externalValidationDashboardSchema.parse({generated_at:"2026-09-13T10:00:00.000Z",capabilities:{can_submit:true,can_approve:true,is_super_admin:false},checklist,cases:[]}).checklist).toHaveLength(9);
  expect(externalValidationSubmitInput.safeParse({locale:"fr",kind:"CNDP_PROCESSING_DECLARATION",environment:"STAGING",referenceCode:"CNDP-001",title:"Déclaration",issuer:"CNDP",issuedOn:"2026-09-13",expiresOn:"",storageReference:"vault://cndp/001",evidenceSha256:"a".repeat(64),scope:"Traitements Matricia",notes:"",idempotencyKey:"11111111-1111-4111-8111-111111111111"}).success).toBe(true);
  expect(externalValidationDecisionInput.safeParse({locale:"ar",caseId:"22222222-2222-4222-8222-222222222222",decision:"APPROVE",reason:"Preuve contrôlée et conforme",ruleVersion:"V4.1-EXTERNAL-1",expectedRowVersion:1,idempotencyKey:"33333333-3333-4333-8333-333333333333"}).success).toBe(true);
 });
});
