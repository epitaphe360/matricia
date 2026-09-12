import { z } from "zod";
import { exactUnits } from "@/lib/volume-procurement/model";

const id=z.string().uuid(),count=z.number().int().nonnegative(),decimal=z.string().regex(/^\d+(?:\.\d+)?$/u);
const summary=z.object({pool_count:count,active_pool_count:count,low_stock_count:count,open_reservation_count:count,client_count:count,provider_count:count});
const pool=z.object({id,agreement_id:id,agreement_version_id:id,agreement_code:z.string(),sku_code:z.string(),unit_code:z.string(),currency:z.string().length(3),contracted_units:decimal,available_units:decimal,reserved_units:decimal,committed_units:decimal,consumed_units:decimal,released_units:decimal,status:z.string(),window_end:z.string(),row_version:decimal,reservation_count:count,client_count:count});
const reservation=z.object({id,pool_id:id,reserved_units:decimal,consumed_units:decimal,released_units:decimal,status:z.string(),expires_at:z.string(),allocated_units:decimal});
const commitment=z.object({id,agreement_version_id:id,capacity_units:decimal,remaining_units:decimal,allocation_share_basis_points:z.number().int(),quality_score_basis_points:z.number().int(),unit_price_minor:z.string().regex(/^\d+$/u),currency:z.string().length(3),status:z.string()});
const allocation=z.object({id,reservation_id:id,provider_commitment_id:id,allocated_units:decimal,consumed_units:decimal,unit_price_minor:z.string().regex(/^\d+$/u),currency:z.string().length(3),allocated_at:z.string()});
export const adminVolumeDashboard=z.object({generated_at:z.string(),capabilities:z.object({can_allocate:z.boolean(),can_consume:z.boolean()}),summary,pools:z.array(pool),reservations:z.array(reservation),commitments:z.array(commitment),allocations:z.array(allocation)});
export type AdminVolumeDashboard=z.infer<typeof adminVolumeDashboard>;
export const adminAllocateInput=z.object({reservationId:id,providerCommitmentId:id,units:exactUnits,idempotencyKey:id});
export const adminConsumeInput=z.object({allocationId:id,units:exactUnits,idempotencyKey:id});
export const localeInput=z.enum(["fr","ar"]);
export type AdminVolumeResult<T>={status:"success";value:T}|{status:"error";reason:"UNAUTHENTICATED"|"FORBIDDEN"|"UNAVAILABLE"|"INVALID_RESPONSE"};
