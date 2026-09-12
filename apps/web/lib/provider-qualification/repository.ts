import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import type { ProviderDashboard } from "./model";

const uuid = z.string().uuid();
const membershipSchema = z.object({ id: uuid, organization_id: uuid, organizations: z.object({ display_name: z.string().min(1) }) });
const profileSchema = z.object({ company_status: z.string(), overall_status: z.string(), activity_summary: z.string(), team_size: z.number().int(), years_experience: z.number().int(), secondary_subcontracting_allowed: z.boolean(), accounting_contact_email: z.string().nullable(), partner_contract_status: z.string(), row_version: z.number().int().positive() });
const serviceSchema = z.object({ id: uuid, service_id: uuid, request_status: z.string(), catalog_services: z.object({ code: z.string() }), provider_qualifications: z.array(z.object({ id: uuid, provider_qualification_decisions: z.object({ status: z.string() }).nullable() })).max(1), provider_capacity_versions: z.array(z.object({ capacity_status: z.string(), available_units: z.number().int().nullable(), lead_time_days: z.number().int() })).max(1) });
const documentSchema = z.object({ id: uuid, version_number: z.number().int().positive(), status: z.string(), expires_on: z.string().nullable(), provider_document_families: z.object({ document_kind: z.string(), code: z.string() }) });
const catalogServiceSchema = z.object({ id: uuid, code: z.string() });

export async function loadProviderDashboard(): Promise<{ status: "success"; dashboard: ProviderDashboard } | { status: "error"; reason: "UNAUTHENTICATED" | "NO_PROVIDER_ORGANIZATION" | "INVALID_RESPONSE" | "QUERY_FAILED" }> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipResult = await client.from("organization_memberships").select("id,organization_id,organizations!inner(display_name),organization_member_roles!inner(role_code,revoked_at)").eq("user_id", auth.user.id).eq("status", "ACTIVE").is("organization_member_roles.revoked_at", null).in("organization_member_roles.role_code", ["PROVIDER_OWNER", "PROVIDER_MANAGER"]).limit(1).maybeSingle();
  if (membershipResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const membership = membershipSchema.safeParse(membershipResult.data);
  if (!membership.success) return { status: "error", reason: membershipResult.data ? "INVALID_RESPONSE" : "NO_PROVIDER_ORGANIZATION" };
  const organizationId = membership.data.organization_id;
  const [profileResult, servicesResult, documentsResult, catalogResult] = await Promise.all([
    client.from("provider_profiles").select("company_status,overall_status,activity_summary,team_size,years_experience,secondary_subcontracting_allowed,accounting_contact_email,partner_contract_status,row_version").eq("provider_organization_id", organizationId).maybeSingle(),
    client.from("provider_services").select("id,service_id,request_status,catalog_services!inner(code),provider_qualifications(id,provider_qualification_decisions!provider_qualifications_current_decision_fk(status)),provider_capacity_versions(capacity_status,available_units,lead_time_days)").eq("provider_organization_id", organizationId).order("version_number", { referencedTable: "provider_capacity_versions", ascending: false }).limit(1, { referencedTable: "provider_capacity_versions" }),
    client.from("provider_document_versions").select("id,version_number,status,expires_on,provider_document_families!inner(document_kind,code)").eq("provider_organization_id", organizationId).order("created_at", { ascending: false }).limit(30),
    client.from("catalog_services").select("id,code").neq("status", "ARCHIVED").order("code").limit(200),
  ]);
  if (profileResult.error || servicesResult.error || documentsResult.error || catalogResult.error) return { status: "error", reason: "QUERY_FAILED" };
  const profile = profileResult.data === null ? null : profileSchema.safeParse(profileResult.data);
  const services = z.array(serviceSchema).safeParse(servicesResult.data);
  const documents = z.array(documentSchema).safeParse(documentsResult.data);
  const catalog = z.array(catalogServiceSchema).safeParse(catalogResult.data);
  if ((profile !== null && !profile.success) || !services.success || !documents.success || !catalog.success) return { status: "error", reason: "INVALID_RESPONSE" };
  return { status: "success", dashboard: { organizationId, organizationName: membership.data.organizations.display_name, profile: profile ? { companyStatus: profile.data.company_status, overallStatus: profile.data.overall_status, activitySummary: profile.data.activity_summary, teamSize: profile.data.team_size, yearsExperience: profile.data.years_experience, secondarySubcontractingAllowed: profile.data.secondary_subcontracting_allowed, accountingContactEmail: profile.data.accounting_contact_email, partnerContractStatus: profile.data.partner_contract_status, rowVersion: profile.data.row_version } : null, services: services.data.map((item) => ({ id: item.id, serviceId: item.service_id, code: item.catalog_services.code, requestStatus: item.request_status, qualificationId: item.provider_qualifications[0]?.id ?? null, qualificationStatus: item.provider_qualifications[0]?.provider_qualification_decisions?.status ?? "NOT_REQUESTED", capacityStatus: item.provider_capacity_versions[0]?.capacity_status ?? "NOT_DECLARED", availableUnits: item.provider_capacity_versions[0]?.available_units ?? null, leadTimeDays: item.provider_capacity_versions[0]?.lead_time_days ?? null })), documents: documents.data.map((item) => ({ id: item.id, kind: item.provider_document_families.document_kind, code: item.provider_document_families.code, version: item.version_number, status: item.status, expiresOn: item.expires_on })), catalogServices: catalog.data } };
}
