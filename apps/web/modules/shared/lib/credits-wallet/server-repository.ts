import { z } from "zod";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { createCreditsRepository } from "./repository";

export async function createServerCreditsRepository(requestedOrganizationId?: string) {
  const c = await getSupabaseServerClient();
  const requested = z.string().uuid().safeParse(requestedOrganizationId).success ? requestedOrganizationId : null;
  const scope = (ids: string[]) => requested && ids.includes(requested) ? [requested] : requested ? [] : ids;
  return createCreditsRepository({
    async user() { const { data } = await c.auth.getUser(); return data.user?.id ?? null; },
    async memberships(id) { return c.from("organization_memberships").select("id,organization_id").eq("user_id", id).eq("status", "ACTIVE").limit(100); },
    async roles(ids) { return ids.length ? c.from("organization_member_roles").select("membership_id,role_code,revoked_at").in("membership_id", ids).limit(300) : { data: [], error: null }; },
    async organizations(ids) { const scoped = scope(ids); return scoped.length ? c.from("organizations").select("id,display_name").in("id", scoped).limit(1) : { data: [], error: null }; },
    async wallets(ids) { const scoped = scope(ids); return scoped.length ? c.from("credit_wallets").select("id,organization_id,unit_code").in("organization_id", scoped).eq("wallet_type", "CLIENT").limit(100) : { data: [], error: null }; },
    async balances(ids) { const scoped = scope(ids); return scoped.length ? c.from("credit_wallet_balances").select("wallet_id,balance").in("organization_id", scoped).eq("wallet_type", "CLIENT").limit(100) : { data: [], error: null }; },
    async lots(ids) { const scoped = scope(ids); return scoped.length ? c.from("credit_lots").select("id,wallet_id,source_type,quantity,expires_at,library_id").in("organization_id", scoped).order("expires_at").limit(500) : { data: [], error: null }; },
    async movements(ids) { const scoped = scope(ids); return scoped.length ? c.from("credit_lot_movements").select("credit_lot_id,movement_type,quantity").in("organization_id", scoped).limit(2000) : { data: [], error: null }; },
    async benefits() {
      const now = Date.now();
      const result = await c.from("benefit_versions").select("id,version,benefit_type,fulfillment_mode,name_fr,name_ar,description_fr,description_ar,credit_cost,currency,effective_from,effective_to,library_id").eq("status", "ACTIVE").limit(300);
      if (result.error || !Array.isArray(result.data)) return result;
      return {
        data: result.data.filter((row) => {
          const from = Date.parse(String(row.effective_from ?? ""));
          const until = row.effective_to == null ? null : Date.parse(String(row.effective_to));
          return Number.isFinite(from) && from <= now && (until === null || (Number.isFinite(until) && until > now));
        }),
        error: null,
      };
    },
    async boxes() { return c.from("box_versions").select("id,version,box_type,name_fr,name_ar,credit_budget,rollover_months,currency,effective_from,effective_to").eq("status", "ACTIVE").limit(100); },
    async customerBoxes(ids) { const scoped = scope(ids); return scoped.length ? c.from("customer_boxes").select("id,organization_id,box_version_id,period_start,period_end").in("organization_id", scoped).order("period_end", { ascending: false }).limit(200) : { data: [], error: null }; },
    async redemptions(ids) { const scoped = scope(ids); return scoped.length ? c.from("benefit_redemptions").select("id,organization_id,wallet_id,benefit_version_id,units,reserved_credits,status,reservation_expires_at,delivery_proof_hash,row_version").in("organization_id", scoped).order("created_at", { ascending: false }).limit(500) : { data: [], error: null }; },
    async rpc(name, input) { return c.rpc(name, input); },
  });
}
