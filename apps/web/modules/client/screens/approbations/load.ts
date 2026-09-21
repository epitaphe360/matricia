import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import type { ClientApprovalRequest } from "./model";

const row = z.object({
  id: z.string().uuid(),
  status: z.enum(["PENDING", "APPROVED", "REJECTED"]),
  row_version: z.coerce.number().int().positive(),
  resource_type: z.string().min(3).max(80),
  resource_id: z.string().min(1).max(200),
  amount_minor: z.union([z.string(), z.number()]).nullable(),
  currency: z.string().regex(/^[A-Z]{3}$/).nullable(),
  requested_at: z.string(),
}).strict();

export async function loadClientApprovals(organizationId: string | null): Promise<ClientApprovalRequest[]> {
  if (!organizationId) return [];
  const client = await getSupabaseServerClient();
  const query = await client
    .from("business_approval_requests")
    .select("id,status,row_version,resource_type,resource_id,amount_minor,currency,requested_at")
    .eq("organization_id", organizationId)
    .order("requested_at", { ascending: false })
    .limit(50);
  if (query.error) return [];
  const parsed = z.array(row).max(50).safeParse(query.data);
  if (!parsed.success) return [];
  return parsed.data.map((item) => ({
    id: item.id,
    status: item.status,
    rowVersion: item.row_version,
    resourceType: item.resource_type,
    resourceId: item.resource_id,
    amountMinor: item.amount_minor === null ? null : String(item.amount_minor),
    currency: item.currency,
    requestedAt: item.requested_at,
  }));
}
