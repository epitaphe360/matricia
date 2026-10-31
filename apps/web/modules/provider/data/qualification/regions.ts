import { z } from "zod";
import { isMoroccoRegionCode } from "@/modules/shared/lib/geo/morocco-regions";
import { uuidSchema } from "./model";

export const providerRegionsInputSchema = z.object({
  organizationId: uuidSchema,
  regionCodes: z.array(z.string().refine(isMoroccoRegionCode)).min(1).max(12)
    .transform((codes) => [...new Set(codes)]),
  reason: z.string().trim().min(3).max(500),
  idempotencyKey: uuidSchema,
});

export const providerRegionsRowSchema = z.object({ region_codes: z.array(z.string()) });

/** Keeps only official codes, so a stale or seeded value never reaches the form as a checked box. */
export function officialRegionCodes(codes: readonly string[]): string[] {
  return codes.filter(isMoroccoRegionCode);
}
