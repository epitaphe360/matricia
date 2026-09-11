"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { isLocale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const organizationRoles = [
  "CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_ACCOUNTING", "CLIENT_MEMBER", "CLIENT_VIEWER",
  "PROVIDER_OWNER", "PROVIDER_MANAGER", "PROVIDER_SALES", "PROVIDER_TECHNICIAN", "PROVIDER_ACCOUNTING", "PROVIDER_VIEWER",
  "FRANCHISE_OWNER", "FRANCHISE_MANAGER", "FRANCHISE_EXPERT", "FRANCHISE_PROVIDER_MANAGER", "FRANCHISE_ACCOUNTING", "FRANCHISE_VIEWER",
] as const;
const approverRoles = new Set(["CLIENT_OWNER", "CLIENT_ADMIN", "PROVIDER_OWNER", "PROVIDER_MANAGER", "FRANCHISE_OWNER", "FRANCHISE_MANAGER"]);
const organizationRoleSchema = z.enum(organizationRoles);
const uuidSchema = z.string().uuid();
const membershipRowSchema = z.object({
  id: uuidSchema,
  organization_id: uuidSchema,
  user_id: uuidSchema,
  status: z.enum(["INVITED", "ACTIVE", "SUSPENDED", "REVOKED"]),
});
const memberRoleRowSchema = z.object({
  membership_id: uuidSchema,
  role_code: organizationRoleSchema,
  revoked_at: z.string().nullable(),
});
const organizationRowSchema = z.object({ id: uuidSchema, display_name: z.string().min(1).max(200) });
const requestRowSchema = z.object({
  id: uuidSchema,
  organization_id: uuidSchema,
  requester_user_id: uuidSchema,
  requested_role_code: organizationRoleSchema,
  status: z.enum(["PENDING", "APPROVED", "REJECTED", "CANCELLED", "EXPIRED"]),
  requires_central_approval: z.boolean(),
  created_at: z.string(),
  decided_at: z.string().nullable(),
});
const requestRoleSchema = z.object({
  organizationId: uuidSchema,
  requestedRoleCode: organizationRoleSchema,
  idempotencyKey: z.string().uuid(),
  locale: z.string().refine(isLocale),
});
const decisionSchema = z.object({
  requestId: uuidSchema,
  decision: z.enum(["APPROVE", "REJECT"]),
  confirmed: z.literal("yes"),
  locale: z.string().refine(isLocale),
});
const rpcOutcomeSchema = z.object({
  outcome: z.enum(["ROLE_REQUESTED", "ROLE_REQUEST_ALREADY_PENDING"]),
}).passthrough();
const securityRequirementSchema = z.object({
  requirement_satisfied: z.boolean(),
  matched_role_codes: z.array(z.string()),
}).passthrough();

export type OrganizationRole = (typeof organizationRoles)[number];
export type RoleOrganization = { id: string; displayName: string; currentRoles: OrganizationRole[] };
export type SafeMembership = {
  id: string;
  organizationName: string | null;
  isCurrentUser: boolean;
  status: "INVITED" | "ACTIVE" | "SUSPENDED" | "REVOKED";
  roles: OrganizationRole[];
};
export type SafeRoleRequest = {
  id: string;
  organizationName: string | null;
  requestedRole: OrganizationRole;
  status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED" | "EXPIRED";
  requiresCentralApproval: boolean;
  isOwn: boolean;
  canDecide: boolean;
  createdAt: string;
  decidedAt: string | null;
};
export type RolesQueryResult =
  | { status: "success"; organizations: RoleOrganization[]; memberships: SafeMembership[]; requests: SafeRoleRequest[] }
  | { status: "error"; reason: "UNAUTHENTICATED" | "UNAVAILABLE" };
export type RoleRequestActionState =
  | { status: "idle" }
  | { status: "success"; outcome: "ROLE_REQUESTED" | "ROLE_REQUEST_ALREADY_PENDING" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "UNAVAILABLE" };
export type RoleDecisionActionState =
  | { status: "idle" }
  | { status: "success"; decision: "APPROVE" | "REJECT" }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "UNAVAILABLE" };

function rolesByMembership(rows: z.infer<typeof memberRoleRowSchema>[]): Map<string, OrganizationRole[]> {
  const result = new Map<string, OrganizationRole[]>();
  for (const row of rows) {
    if (row.revoked_at !== null) continue;
    const roles = result.get(row.membership_id) ?? [];
    roles.push(row.role_code);
    result.set(row.membership_id, roles);
  }
  return result;
}

export async function listOrganizationRoles(): Promise<RolesQueryResult> {
  const supabase = await getSupabaseServerClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) return { status: "error", reason: "UNAUTHENTICATED" };

  const { data: rawOwn, error: ownError } = await supabase
    .from("organization_memberships")
    .select("id,organization_id,user_id,status")
    .eq("user_id", user.id);
  if (ownError) return { status: "error", reason: "UNAVAILABLE" };
  const ownMemberships = z.array(membershipRowSchema).safeParse(rawOwn);
  if (!ownMemberships.success) return { status: "error", reason: "UNAVAILABLE" };
  const ownOrganizationIds = [...new Set(ownMemberships.data.map((row) => row.organization_id))];

  const [membershipsResult, organizationsResult, requestsResult, securityResult] = await Promise.all([
    ownOrganizationIds.length > 0
      ? supabase.from("organization_memberships").select("id,organization_id,user_id,status").in("organization_id", ownOrganizationIds)
      : Promise.resolve({ data: [], error: null }),
    ownOrganizationIds.length > 0
      ? supabase.from("organizations").select("id,display_name").in("id", ownOrganizationIds)
      : Promise.resolve({ data: [], error: null }),
    supabase
      .from("organization_access_requests")
      .select("id,organization_id,requester_user_id,requested_role_code,status,requires_central_approval,created_at,decided_at")
      .order("created_at", { ascending: false }),
    supabase.rpc("get_my_account_security_requirement"),
  ]);
  if (membershipsResult.error || organizationsResult.error || requestsResult.error) {
    return { status: "error", reason: "UNAVAILABLE" };
  }
  const memberships = z.array(membershipRowSchema).safeParse(membershipsResult.data);
  const organizations = z.array(organizationRowSchema).safeParse(organizationsResult.data);
  const requests = z.array(requestRowSchema).safeParse(requestsResult.data);
  if (!memberships.success || !organizations.success || !requests.success) {
    return { status: "error", reason: "UNAVAILABLE" };
  }

  const membershipIds = memberships.data.map((row) => row.id);
  const { data: rawRoles, error: rolesError } = membershipIds.length > 0
    ? await supabase.from("organization_member_roles").select("membership_id,role_code,revoked_at").in("membership_id", membershipIds)
    : { data: [], error: null };
  if (rolesError) return { status: "error", reason: "UNAVAILABLE" };
  const memberRoles = z.array(memberRoleRowSchema).safeParse(rawRoles);
  if (!memberRoles.success) return { status: "error", reason: "UNAVAILABLE" };

  const groupedRoles = rolesByMembership(memberRoles.data);
  const names = new Map(organizations.data.map((organization) => [organization.id, organization.display_name]));
  const ownActiveMemberships = ownMemberships.data.filter((row) => row.status === "ACTIVE");
  const ownApproverOrganizationIds = new Set(
    ownActiveMemberships
      .filter((membership) => (groupedRoles.get(membership.id) ?? []).some((role) => approverRoles.has(role)))
      .map((membership) => membership.organization_id),
  );
  const securityRequirements = securityResult.error
    ? null
    : z.array(securityRequirementSchema).safeParse(securityResult.data);
  const securityRequirement = securityRequirements?.success && securityRequirements.data.length === 1
    ? securityRequirements.data[0]
    : null;
  const isCentralApprover = Boolean(
    securityRequirement?.requirement_satisfied
      && securityRequirement.matched_role_codes.some((role) =>
        role === "SUPER_ADMIN" || role === "MATRICIA_ADMIN" || role === "COMPLIANCE_MANAGER"),
  );

  return {
    status: "success",
    organizations: ownActiveMemberships.map((membership) => ({
      id: membership.organization_id,
      displayName: names.get(membership.organization_id) ?? "",
      currentRoles: groupedRoles.get(membership.id) ?? [],
    })),
    memberships: memberships.data.map((membership) => ({
      id: membership.id,
      organizationName: names.get(membership.organization_id) ?? null,
      isCurrentUser: membership.user_id === user.id,
      status: membership.status,
      roles: groupedRoles.get(membership.id) ?? [],
    })),
    requests: requests.data.map((request) => ({
      id: request.id,
      organizationName: names.get(request.organization_id) ?? null,
      requestedRole: request.requested_role_code,
      status: request.status,
      requiresCentralApproval: request.requires_central_approval,
      isOwn: request.requester_user_id === user.id,
      canDecide: request.status === "PENDING"
        && request.requester_user_id !== user.id
        && (isCentralApprover
          || (!request.requires_central_approval && ownApproverOrganizationIds.has(request.organization_id))),
      createdAt: request.created_at,
      decidedAt: request.decided_at,
    })),
  };
}

export async function requestAdditionalRole(
  _previousState: RoleRequestActionState,
  formData: FormData,
): Promise<RoleRequestActionState> {
  const parsed = requestRoleSchema.safeParse({
    organizationId: formData.get("organizationId"),
    requestedRoleCode: formData.get("requestedRoleCode"),
    idempotencyKey: formData.get("idempotencyKey"),
    locale: formData.get("locale"),
  });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const supabase = await getSupabaseServerClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) return { status: "error", reason: "UNAUTHENTICATED" };
  const { data, error } = await supabase.rpc("request_additional_organization_role", {
    p_organization_id: parsed.data.organizationId,
    p_requested_role_code: parsed.data.requestedRoleCode,
    p_idempotency_key: parsed.data.idempotencyKey,
    p_correlation_id: randomUUID(),
  });
  if (error) return { status: "error", reason: "UNAVAILABLE" };
  const outcome = rpcOutcomeSchema.safeParse(data);
  if (!outcome.success) return { status: "error", reason: "UNAVAILABLE" };
  revalidatePath("/" + parsed.data.locale + "/organisation/roles");
  return { status: "success", outcome: outcome.data.outcome };
}

export async function decideRoleRequest(
  _previousState: RoleDecisionActionState,
  formData: FormData,
): Promise<RoleDecisionActionState> {
  const parsed = decisionSchema.safeParse({
    requestId: formData.get("requestId"),
    decision: formData.get("decision"),
    confirmed: formData.get("confirmed"),
    locale: formData.get("locale"),
  });
  if (!parsed.success) return { status: "error", reason: "VALIDATION" };
  const supabase = await getSupabaseServerClient();
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) return { status: "error", reason: "UNAUTHENTICATED" };
  const { error } = await supabase.rpc("decide_organization_access_request", {
    p_request_id: parsed.data.requestId,
    p_approve: parsed.data.decision === "APPROVE",
    p_correlation_id: randomUUID(),
  });
  if (error) return { status: "error", reason: "UNAVAILABLE" };
  revalidatePath("/" + parsed.data.locale + "/organisation/roles");
  return { status: "success", decision: parsed.data.decision };
}
