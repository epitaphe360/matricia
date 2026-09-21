import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { ProviderDashboard } from "./model";

const uuid = z.string().uuid();
const membershipSchema = z.object({ id: uuid, organization_id: uuid, organizations: z.object({ display_name: z.string().min(1) }) });
const profileSchema = z.object({ company_status: z.string(), overall_status: z.string(), activity_summary: z.string(), team_size: z.number().int(), years_experience: z.number().int(), secondary_subcontracting_allowed: z.boolean(), accounting_contact_email: z.string().nullable(), partner_contract_status: z.string(), row_version: z.number().int().positive() });
const serviceSchema = z.object({ id: uuid, service_id: uuid, request_status: z.string(), catalog_services: z.object({ code: z.string() }), provider_qualifications: z.array(z.object({ id: uuid, provider_qualification_decisions: z.object({ status: z.string() }).nullable() })).max(1), provider_capacity_versions: z.array(z.object({ capacity_status: z.string(), available_units: z.number().int().nullable(), lead_time_days: z.number().int() })).max(1) });
const documentSchema = z.object({ id: uuid, version_number: z.number().int().positive(), status: z.string(), expires_on: z.string().nullable(), provider_document_families: z.object({ document_kind: z.string(), code: z.string() }) });
const catalogServiceSchema = z.object({ id: uuid, code: z.string(), library_id: uuid, primary_subcategory_id: uuid, current_published_version_id: uuid });
const catalogLibrarySchema = z.object({ id: uuid, current_published_version_id: uuid });
const catalogSubcategorySchema = z.object({ id: uuid, current_published_version_id: uuid });
const localizedVersionSchema = z.object({ id: uuid, name_fr: z.string().min(1), name_ar: z.string().min(1) });
const eligibilitySchema = z.object({
  eligible: z.boolean(),
  reasons: z.array(z.string()),
  qualification_status: z.string(),
  capacity_status: z.string(),
  decision_version: z.number().int().positive().nullable().optional(),
  rule_version: z.string().nullable().optional(),
  checked_at: z.string().nullable().optional(),
});

export type ProviderDashboardProjectionDiagnostic = "PROFILE_SHAPE_INVALID" | "SERVICES_SHAPE_INVALID" | "DOCUMENTS_SHAPE_INVALID" | "CATALOG_SHAPE_INVALID" | "PROVIDER_SERVICE_LABEL_MISSING";
export type ProviderDashboardErrorReason = "UNAUTHENTICATED" | "NO_PROVIDER_ORGANIZATION" | "MEMBERSHIP_QUERY_FAILED" | "MEMBERSHIP_SHAPE_INVALID" | "PROFILE_QUERY_FAILED" | "SERVICES_QUERY_FAILED" | "DOCUMENTS_QUERY_FAILED" | "CATALOG_QUERY_FAILED" | "HISTORICAL_SERVICE_QUERY_FAILED" | "HISTORICAL_SERVICE_SHAPE_INVALID" | "LOCALIZATION_QUERY_FAILED" | "LOCALIZATION_SHAPE_INVALID" | "ELIGIBILITY_QUERY_FAILED" | "ELIGIBILITY_SHAPE_INVALID" | ProviderDashboardProjectionDiagnostic;

export function diagnoseProviderDashboardProjection(input: { profile: unknown; services: unknown; documents: unknown; catalog: unknown }): ProviderDashboardProjectionDiagnostic | null {
  if (input.profile !== null && !profileSchema.safeParse(input.profile).success) return "PROFILE_SHAPE_INVALID";
  if (!z.array(serviceSchema).safeParse(input.services).success) return "SERVICES_SHAPE_INVALID";
  if (!z.array(documentSchema).safeParse(input.documents).success) return "DOCUMENTS_SHAPE_INVALID";
  if (!z.array(catalogServiceSchema).safeParse(input.catalog).success) return "CATALOG_SHAPE_INVALID";
  return null;
}

export function diagnoseProviderServiceLabelCoverage(serviceIds: readonly string[], localizedServiceIds: ReadonlySet<string>): ProviderDashboardProjectionDiagnostic | null {
  return serviceIds.some((serviceId) => !localizedServiceIds.has(serviceId)) ? "PROVIDER_SERVICE_LABEL_MISSING" : null;
}

export async function loadProviderDashboard(): Promise<{ status: "success"; dashboard: ProviderDashboard } | { status: "error"; reason: ProviderDashboardErrorReason }> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipResult = await client.from("organization_memberships").select("id,organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", ["PROVIDER_OWNER", "PROVIDER_MANAGER"]).limit(1).maybeSingle();
  if (membershipResult.error) return { status: "error", reason: "MEMBERSHIP_QUERY_FAILED" };
  const membership = membershipSchema.safeParse(membershipResult.data);
  if (!membership.success) return { status: "error", reason: membershipResult.data ? "MEMBERSHIP_SHAPE_INVALID" : "NO_PROVIDER_ORGANIZATION" };
  const organizationId = membership.data.organization_id;
  const [profileResult, servicesResult, documentsResult, catalogResult] = await Promise.all([
    client.from("provider_profiles").select("company_status,overall_status,activity_summary,team_size,years_experience,secondary_subcontracting_allowed,accounting_contact_email,partner_contract_status,row_version").eq("provider_organization_id", organizationId).maybeSingle(),
    client.from("provider_services").select("id,service_id,request_status,catalog_services!inner(code),provider_qualifications(id,provider_qualification_decisions!provider_qualifications_current_decision_fk(status)),provider_capacity_versions(capacity_status,available_units,lead_time_days)").eq("provider_organization_id", organizationId).order("version_number", { referencedTable: "provider_capacity_versions", ascending: false }).limit(1, { referencedTable: "provider_capacity_versions" }),
    client.from("provider_document_versions").select("id,version_number,status,expires_on,provider_document_families!inner(document_kind,code)").eq("provider_organization_id", organizationId).order("created_at", { ascending: false }).limit(30),
    client.from("catalog_services").select("id,code,library_id,primary_subcategory_id,current_published_version_id").eq("status", "PUBLISHED").not("library_id", "is", null).not("primary_subcategory_id", "is", null).not("current_published_version_id", "is", null).order("code").limit(200),
  ]);
  if (profileResult.error) return { status: "error", reason: "PROFILE_QUERY_FAILED" };
  if (servicesResult.error) return { status: "error", reason: "SERVICES_QUERY_FAILED" };
  if (documentsResult.error) return { status: "error", reason: "DOCUMENTS_QUERY_FAILED" };
  if (catalogResult.error) return { status: "error", reason: "CATALOG_QUERY_FAILED" };
  const projectionDiagnostic=diagnoseProviderDashboardProjection({ profile: profileResult.data, services: servicesResult.data, documents: documentsResult.data, catalog: catalogResult.data });
  if (projectionDiagnostic) return { status: "error", reason: projectionDiagnostic };
  const profile = profileResult.data === null ? null : profileSchema.safeParse(profileResult.data);
  const services = z.array(serviceSchema).safeParse(servicesResult.data);
  const documents = z.array(documentSchema).safeParse(documentsResult.data);
  const catalog = z.array(catalogServiceSchema).safeParse(catalogResult.data);
  if ((profile !== null && !profile.success) || !services.success || !documents.success || !catalog.success) return { status: "error", reason: "CATALOG_SHAPE_INVALID" };
  const publishedIds=new Set(catalog.data.map((item)=>item.id));
  const historicalIds=[...new Set(services.data.map((item)=>item.service_id).filter((id)=>!publishedIds.has(id)))];
  const historicalResult=historicalIds.length?await client.from("catalog_services").select("id,code,library_id,primary_subcategory_id,current_published_version_id").in("id",historicalIds).not("library_id","is",null).not("primary_subcategory_id","is",null).not("current_published_version_id","is",null).limit(200):{data:[],error:null};
  if(historicalResult.error)return{status:"error",reason:"HISTORICAL_SERVICE_QUERY_FAILED"};
  const historical=z.array(catalogServiceSchema).safeParse(historicalResult.data);
  if(!historical.success)return{status:"error",reason:"HISTORICAL_SERVICE_SHAPE_INVALID"};
  const catalogForLabels=[...catalog.data,...historical.data];
  const libraryIds=[...new Set(catalogForLabels.map((item)=>item.library_id))];
  const categoryIds=[...new Set(catalogForLabels.map((item)=>item.primary_subcategory_id))];
  const [serviceVersionsResult,librariesResult,categoriesResult]=await Promise.all([
    client.from("catalog_service_versions").select("id,name_fr,name_ar").in("id",catalogForLabels.map((item)=>item.current_published_version_id)).eq("status","PUBLISHED").limit(200),
    client.from("catalog_libraries").select("id,current_published_version_id").in("id",libraryIds).eq("status","PUBLISHED").limit(20),
    client.from("catalog_subcategories").select("id,current_published_version_id").in("id",categoryIds).eq("status","PUBLISHED").limit(100),
  ]);
  if(serviceVersionsResult.error||librariesResult.error||categoriesResult.error)return{status:"error",reason:"LOCALIZATION_QUERY_FAILED"};
  const libraries=z.array(catalogLibrarySchema).safeParse(librariesResult.data);
  const categories=z.array(catalogSubcategorySchema).safeParse(categoriesResult.data);
  const serviceVersions=z.array(localizedVersionSchema).safeParse(serviceVersionsResult.data);
  if(!libraries.success||!categories.success||!serviceVersions.success)return{status:"error",reason:"LOCALIZATION_SHAPE_INVALID"};
  const [libraryVersionsResult,categoryVersionsResult]=await Promise.all([
    client.from("catalog_library_versions").select("id,name_fr,name_ar").in("id",libraries.data.map((item)=>item.current_published_version_id)).eq("status","PUBLISHED").limit(20),
    client.from("catalog_subcategory_versions").select("id,name_fr,name_ar").in("id",categories.data.map((item)=>item.current_published_version_id)).eq("status","PUBLISHED").limit(100),
  ]);
  if(libraryVersionsResult.error||categoryVersionsResult.error)return{status:"error",reason:"LOCALIZATION_QUERY_FAILED"};
  const libraryVersions=z.array(localizedVersionSchema).safeParse(libraryVersionsResult.data);
  const categoryVersions=z.array(localizedVersionSchema).safeParse(categoryVersionsResult.data);
  if(!libraryVersions.success||!categoryVersions.success)return{status:"error",reason:"LOCALIZATION_SHAPE_INVALID"};
  const localized=(values:z.infer<typeof localizedVersionSchema>[])=>new Map(values.map((item)=>[item.id,{fr:item.name_fr,ar:item.name_ar}]));
  const serviceNames=localized(serviceVersions.data),libraryNames=localized(libraryVersions.data),categoryNames=localized(categoryVersions.data);
  const libraryVersionById=new Map(libraries.data.map((item)=>[item.id,item.current_published_version_id]));
  const categoryVersionById=new Map(categories.data.map((item)=>[item.id,item.current_published_version_id]));
  const labelsByServiceId=new Map(catalogForLabels.flatMap((item)=>{const label=serviceNames.get(item.current_published_version_id),libraryLabel=libraryNames.get(libraryVersionById.get(item.library_id)??""),categoryLabel=categoryNames.get(categoryVersionById.get(item.primary_subcategory_id)??"");return label&&libraryLabel&&categoryLabel?[[item.id,{code:item.code,label,libraryLabel,categoryLabel}]as const]:[]}));
  if(diagnoseProviderServiceLabelCoverage(services.data.map((item)=>item.service_id),new Set(labelsByServiceId.keys())))return{status:"error",reason:"PROVIDER_SERVICE_LABEL_MISSING"};
  const eligibilityResults = await Promise.all(services.data.map((item) => client.rpc("explain_provider_service_eligibility", { p_provider_organization_id: organizationId, p_service_id: item.service_id })));
  if (eligibilityResults.some((result) => result.error)) return { status: "error", reason: "ELIGIBILITY_QUERY_FAILED" };
  const eligibility = z.array(eligibilitySchema).safeParse(eligibilityResults.map((result) => result.data));
  if (!eligibility.success) return { status: "error", reason: "ELIGIBILITY_SHAPE_INVALID" };
  return { status: "success", dashboard: { organizationId, organizationName: membership.data.organizations.display_name, profile: profile ? { companyStatus: profile.data.company_status, overallStatus: profile.data.overall_status, activitySummary: profile.data.activity_summary, teamSize: profile.data.team_size, yearsExperience: profile.data.years_experience, secondarySubcontractingAllowed: profile.data.secondary_subcontracting_allowed, accountingContactEmail: profile.data.accounting_contact_email, partnerContractStatus: profile.data.partner_contract_status, rowVersion: profile.data.row_version } : null, services: services.data.map((item, index) => { const explanation = eligibility.data[index]!,labels=labelsByServiceId.get(item.service_id)!; return { id: item.id, serviceId: item.service_id, ...labels, requestStatus: item.request_status, qualificationId: item.provider_qualifications[0]?.id ?? null, qualificationStatus: explanation.qualification_status, capacityStatus: explanation.capacity_status, availableUnits: item.provider_capacity_versions[0]?.available_units ?? null, leadTimeDays: item.provider_capacity_versions[0]?.lead_time_days ?? null, eligibility: { eligible: explanation.eligible, reasons: explanation.reasons, decisionVersion: explanation.decision_version ?? null, ruleVersion: explanation.rule_version ?? null, checkedAt: explanation.checked_at ?? null } }; }), documents: documents.data.map((item) => ({ id: item.id, kind: item.provider_document_families.document_kind, code: item.provider_document_families.code, version: item.version_number, status: item.status, expiresOn: item.expires_on })), catalogServices: catalog.data.flatMap((item)=>{const labels=labelsByServiceId.get(item.id);return labels?[{id:item.id,...labels}]:[]}) } };
}
