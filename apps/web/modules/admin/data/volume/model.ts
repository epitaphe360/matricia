import { z } from "zod";
import { exactUnits } from "@/modules/shared/lib/volume-procurement/model";

const id=z.string().uuid(),count=z.number().int().nonnegative(),decimal=z.string().regex(/^\d+(?:\.\d+)?$/u);
const summary=z.object({pool_count:count,active_pool_count:count,low_stock_count:count,open_reservation_count:count,client_count:count,provider_count:count,draft_agreement_count:count.optional()});
const pool=z.object({id,agreement_id:id,agreement_version_id:id,agreement_code:z.string(),sku_code:z.string(),unit_code:z.string(),currency:z.string().length(3),contracted_units:decimal,available_units:decimal,reserved_units:decimal,committed_units:decimal,consumed_units:decimal,released_units:decimal,status:z.string(),window_end:z.string(),row_version:decimal,reservation_count:count,client_count:count});
const reservation=z.object({id,pool_id:id,reserved_units:decimal,consumed_units:decimal,released_units:decimal,status:z.string(),expires_at:z.string(),allocated_units:decimal});
const commitment=z.object({id,agreement_version_id:id,capacity_units:decimal,remaining_units:decimal,allocation_share_basis_points:z.number().int(),quality_score_basis_points:z.number().int(),unit_price_minor:z.string().regex(/^\d+$/u),currency:z.string().length(3),status:z.string()});
const allocation=z.object({id,reservation_id:id,provider_commitment_id:id,allocated_units:decimal,consumed_units:decimal,unit_price_minor:z.string().regex(/^\d+$/u),currency:z.string().length(3),allocated_at:z.string()});
const agreement=z.object({id,agreement_code:z.string(),status:z.string(),sku_code:z.string(),currency:z.string().length(3).nullable(),valid_from:z.string().nullable(),valid_to:z.string().nullable(),forecast_units:decimal.nullable(),payment_model:z.string().nullable(),owner_organization_id:id,agreement_version_id:id.optional(),minimum_commitment_units:decimal.nullable().optional(),maximum_units:decimal.nullable().optional(),pool_id:id.nullable().optional(),pool_status:z.string().nullable().optional()});
const sku=z.object({id,code:z.string(),unit_code:z.string(),currency:z.string().length(3),reference_cost_minor:z.string().regex(/^\d+$/u)});
const profit=z.object({agreement_code:z.string(),sku_code:z.string(),currency:z.string().length(3),consumed_units:decimal,consumed_cost_minor:z.string().regex(/^\d+$/u),reference_cost_minor:z.string().regex(/^\d+$/u)});
export const adminVolumeDashboard=z.object({generated_at:z.string(),capabilities:z.object({can_allocate:z.boolean(),can_consume:z.boolean(),can_negotiate:z.boolean().optional(),can_activate_pool:z.boolean().optional()}),summary,pools:z.array(pool),reservations:z.array(reservation),commitments:z.array(commitment),allocations:z.array(allocation),agreements:z.array(agreement).optional(),skus:z.array(sku).optional(),profitability:z.array(profit).optional()});
export type AdminVolumeDashboard=z.infer<typeof adminVolumeDashboard>;
export const adminAllocateInput=z.object({reservationId:id,providerCommitmentId:id,units:exactUnits,idempotencyKey:id});
export const adminConsumeInput=z.object({allocationId:id,units:exactUnits,idempotencyKey:id});
export const localeInput=z.enum(["fr","ar"]);
export type AdminVolumeResult<T>={status:"success";value:T}|{status:"error";reason:"UNAUTHENTICATED"|"FORBIDDEN"|"UNAVAILABLE"|"INVALID_RESPONSE"};
