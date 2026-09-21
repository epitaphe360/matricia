import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { AdminCommandCenter } from "./model";

const id = z.string().uuid();
const queue = z.object({ id, queue_key: z.string(), label_fr: z.string(), label_ar: z.string() });
const platformRole = z.object({ role_code: z.string() }).strict();
const work = z.object({
  id,
  queue_version_id: id,
  organization_id: id.nullable(),
  source_kind: z.string(),
  resource_type: z.string(),
  resource_id: z.string(),
  title_fr: z.string(),
  title_ar: z.string(),
  priority: z.enum(["CRITICAL", "HIGH", "MEDIUM", "LOW"]),
  status: z.string(),
  due_at: z.string(),
  assigned_to: id.nullable(),
  row_version: z.number().int().positive(),
});
const action = z.object({
  id,
  work_item_id: id.nullable(),
  organization_id: id.nullable(),
  action_type: z.string(),
  target_environment: z.string(),
  resource_type: z.string(),
  resource_id: z.string(),
  reason: z.string(),
  approvals_required: z.number().int().positive(),
  status: z.string(),
  requested_by: id,
  requested_at: z.string(),
  row_version: z.number().int().positive(),
});
export type AdminLoadResult = { status: "success"; dashboard: AdminCommandCenter } | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "QUERY_FAILED" | "INVALID_RESPONSE" };

export async function loadAdminCommandCenter(): Promise<AdminLoadResult> {
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const roleQuery = await client.from("platform_user_roles").select("role_code").eq("user_id", auth.user.id).is("revoked_at", null).in("role_code", ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "FINANCE_MANAGER", "DISPUTE_MANAGER", "LIBRARY_MANAGER", "SUPPORT_AGENT", "READ_ONLY_AUDITOR"]).limit(20);
  if (roleQuery.error) return { status: "error", reason: "QUERY_FAILED" };
  const roleRows = z.array(platformRole).safeParse(roleQuery.data);
  if (!roleRows.success) return { status: "error", reason: "INVALID_RESPONSE" };
  if (roleRows.data.length === 0) return { status: "error", reason: "FORBIDDEN" };
  const roles = new Set(roleRows.data.map((item) => item.role_code));
  const readOnly = roles.has("READ_ONLY_AUDITOR") && ![...roles].some((item) => item !== "READ_ONLY_AUDITOR");
  const central = roles.has("SUPER_ADMIN") || roles.has("MATRICIA_ADMIN");
  const canRequest = !readOnly && [...roles].some((item) => ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "FINANCE_MANAGER", "DISPUTE_MANAGER", "LIBRARY_MANAGER", "SUPPORT_AGENT"].includes(item));
  const decisionRole = !readOnly && [...roles].some((item) => ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "FINANCE_MANAGER", "DISPUTE_MANAGER", "LIBRARY_MANAGER"].includes(item));
  const [workQuery, actionQuery] = await Promise.all([
    client.from("admin_work_items").select("id,queue_version_id,organization_id,source_kind,resource_type,resource_id,title_fr,title_ar,priority,status,due_at,assigned_to,row_version").in("status", ["OPEN", "CLAIMED", "WAITING_INFORMATION"]).order("severity_rank", { ascending: false }).order("due_at").limit(100),
    client.from("admin_operational_action_requests").select("id,work_item_id,organization_id,action_type,target_environment,resource_type,resource_id,reason,approvals_required,status,requested_by,requested_at,row_version").eq("status", "PENDING_APPROVAL").order("requested_at").limit(100),
  ]);
  if (workQuery.error || actionQuery.error) return { status: "error", reason: "QUERY_FAILED" };
  const workRows = z.array(work).safeParse(workQuery.data);
  const actionRows = z.array(action).safeParse(actionQuery.data);
  if (!workRows.success || !actionRows.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const queueIds = [...new Set(workRows.data.map((item) => item.queue_version_id))];
  const queueQuery = queueIds.length
    ? await client.from("admin_queue_versions").select("id,queue_key,label_fr,label_ar").in("id", queueIds).limit(100)
    : { data: [], error: null };
  if (queueQuery.error) return { status: "error", reason: "QUERY_FAILED" };
  const queueRows = z.array(queue).safeParse(queueQuery.data);
  if (!queueRows.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const queues = new Map(queueRows.data.map((item) => [item.id, item]));
  return {
    status: "success",
    dashboard: {
      capabilities: { requestAction: canRequest },
      workItems: workRows.data.flatMap((item) => {
        const version = queues.get(item.queue_version_id);
        if (!version) return [];
        return [{
          id: item.id,
          queueKey: version.queue_key,
          queueLabelFr: version.label_fr,
          queueLabelAr: version.label_ar,
          organizationId: item.organization_id,
          sourceKind: item.source_kind,
          resourceType: item.resource_type,
          resourceId: item.resource_id,
          titleFr: item.title_fr,
          titleAr: item.title_ar,
          priority: item.priority,
          status: item.status,
          dueAt: item.due_at,
          assignedTo: item.assigned_to,
          rowVersion: item.row_version,
          canClaim: !readOnly && item.status === "OPEN",
          canResolve: !readOnly && ["CLAIMED", "WAITING_INFORMATION"].includes(item.status) && (item.assigned_to === auth.user.id || central),
        }];
      }),
      actions: actionRows.data.map((item) => ({
        id: item.id,
        workItemId: item.work_item_id,
        organizationId: item.organization_id,
        actionType: item.action_type,
        targetEnvironment: item.target_environment,
        resourceType: item.resource_type,
        resourceId: item.resource_id,
        reason: item.reason,
        approvalsRequired: item.approvals_required,
        status: item.status,
        requestedBy: item.requested_by,
        requestedAt: item.requested_at,
        rowVersion: item.row_version,
        canDecide: decisionRole && item.requested_by !== auth.user.id,
      })),
    },
  };
}
