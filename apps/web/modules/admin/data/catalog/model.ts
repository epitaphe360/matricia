import { z } from "zod";

const id = z.string().uuid();
const minor = z.string().regex(/^\d+$/u);
const timestamp = z.string().min(10);

export const adminCommerceCatalogSchema = z.object({
  generated_at: timestamp,
  capabilities: z.object({ can_write: z.boolean(), can_activate: z.boolean() }),
  packs: z.array(z.object({
    id, pack_id: id, code: z.string(), version: z.number().int().positive(), status: z.string(),
    name_fr: z.string(), name_ar: z.string(), quantity: minor, price_minor: minor,
    currency: z.string().length(3), validity_days: z.number().int().positive(),
  })),
  promotions: z.array(z.object({
    id, code: z.string(), version: z.number().int().positive(), status: z.string(),
    name_fr: z.string(), name_ar: z.string(), bonus_credits: minor, validity_days: z.number().int().positive(),
    effective_from: timestamp, effective_until: timestamp.nullable(), approval_reference: z.string().nullable(),
  })),
  parameters: z.array(z.object({
    id, parameter_key: z.string(), version: z.number().int().positive(), status: z.string(),
    value_integer: minor, effective_from: timestamp, change_reason: z.string(),
  })),
});

export type AdminCommerceCatalog = z.infer<typeof adminCommerceCatalogSchema>;

export const adminVolumeDemandSchema = z.object({
  generated_at: timestamp,
  default_reservation_ttl_hours: z.string().regex(/^\d+$/u).nullable(),
  history: z.array(z.object({
    month_start: z.string(), sku_code: z.string(), reserved_units: z.string(), consumed_units: z.string(),
    reservation_count: z.number().int().nonnegative(),
  })),
  forecasts: z.array(z.object({
    agreement_code: z.string(), sku_code: z.string(), status: z.string(),
    forecast_units: z.string(), valid_from: z.string(), valid_to: z.string(),
  })),
});

export type AdminVolumeDemand = z.infer<typeof adminVolumeDemandSchema>;

export const adminDocumentVaultSchema = z.object({
  generated_at: timestamp,
  warning_days: z.number().int().positive().nullable(),
  documents: z.array(z.object({
    id, organization_id: id, organization_name: z.string(), source: z.enum(["CLIENT", "PROVIDER"]),
    document_type: z.string(), status: z.string(), expires_on: z.string().nullable(),
    version: z.number().int().positive(), expiring: z.boolean(),
  })),
});

export type AdminDocumentVault = z.infer<typeof adminDocumentVaultSchema>;
export type AdminCatalogErrorReason = "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE";
export type AdminCatalogResult<T> = { status: "success"; value: T } | { status: "error"; reason: AdminCatalogErrorReason };
