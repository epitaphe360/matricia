import { z } from "zod";

export const adminV41Modules = ["procurement","supplier_ap","own_payments","treasury","finops","margins","signature","privacy","third_parties","incidents","operations","contracts_disputes","catalog_marketing"] as const;
export type AdminV41Module = (typeof adminV41Modules)[number];

const count = z.number().int().nonnegative();
export const adminV41OverviewSchema = z.object({
  generated_at: z.string().datetime({ offset: true }),
  limit: z.number().int().min(1).max(100),
  financial_flows: z.object({ client_to_provider_declared: count, matricia_own_revenue: count, provider_commission_receipts: count }).strict(),
  modules: z.array(z.object({ key: z.enum(adminV41Modules), open: count, exceptions: count }).strict()).length(adminV41Modules.length),
}).strict();

export type AdminV41Overview = z.infer<typeof adminV41OverviewSchema>;
export type AdminV41Result = { status:"success"; value:AdminV41Overview } | { status:"error"; reason:"UNAUTHENTICATED"|"FORBIDDEN"|"UNAVAILABLE"|"INVALID_RESPONSE" };

export const externalValidationKinds = ["CNDP_PROCESSING_DECLARATION","CNDP_TRANSFER_AUTHORIZATION","SIGNATURE_PROVIDER_CERTIFICATION","CATALOG_ARABIC_REVIEW","CATALOG_EXPERT_REVIEW","CATALOG_OPPORTUNITY_MAPPING","RESTORE_TEST_EVIDENCE","SECURITY_PENETRATION_EVIDENCE","PRODUCTION_AUTHORIZATION"] as const;
export type ExternalValidationKind = (typeof externalValidationKinds)[number];
const nullableUuid = z.string().uuid().nullable();
export const externalValidationDashboardSchema = z.object({
 generated_at:z.string().datetime({offset:true}),
 capabilities:z.object({can_submit:z.boolean(),can_approve:z.boolean(),is_super_admin:z.boolean()}).strict(),
 checklist:z.array(z.object({kind:z.enum(externalValidationKinds),approved:z.boolean()}).strict()).length(externalValidationKinds.length),
 cases:z.array(z.object({id:z.string().uuid(),kind:z.enum(externalValidationKinds),environment:z.enum(["DEVELOPMENT","STAGING","PRODUCTION"]),reference_code:z.string(),title:z.string(),status:z.enum(["SUBMITTED","APPROVED","REJECTED"]),row_version:z.number().int().positive(),submitted_by:z.string().uuid(),reviewed_by:nullableUuid,created_at:z.string().datetime({offset:true}),issuer:z.string(),issued_on:z.string(),expires_on:z.string().nullable(),storage_reference:z.string(),evidence_sha256:z.string().regex(/^[0-9a-f]{64}$/),metadata:z.record(z.string(),z.unknown())}).strict()).max(100),
}).strict();
export type ExternalValidationDashboard=z.infer<typeof externalValidationDashboardSchema>;
export type ExternalValidationResult={status:"success";value:ExternalValidationDashboard}|{status:"error";reason:"UNAUTHENTICATED"|"FORBIDDEN"|"UNAVAILABLE"|"INVALID_RESPONSE"};

const uuid=z.string().uuid();
export const externalValidationSubmitInput=z.object({locale:z.enum(["fr","ar"]),kind:z.enum(externalValidationKinds),environment:z.enum(["DEVELOPMENT","STAGING","PRODUCTION"]),referenceCode:z.string().trim().min(3).max(160),title:z.string().trim().min(3).max(240),issuer:z.string().trim().min(2).max(160),issuedOn:z.string().date(),expiresOn:z.union([z.string().date(),z.literal("")]),storageReference:z.string().trim().min(3).max(500),evidenceSha256:z.string().regex(/^[0-9a-f]{64}$/),scope:z.string().trim().min(3).max(1000),notes:z.string().trim().max(2000),idempotencyKey:uuid});
export const externalValidationDecisionInput=z.object({locale:z.enum(["fr","ar"]),caseId:uuid,decision:z.enum(["APPROVE","REJECT"]),reason:z.string().trim().min(10).max(2000),ruleVersion:z.string().trim().toUpperCase().regex(/^[A-Z][A-Z0-9_.-]{2,79}$/),expectedRowVersion:z.coerce.number().int().positive(),idempotencyKey:uuid});
