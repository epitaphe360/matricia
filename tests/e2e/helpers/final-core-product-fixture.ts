import { existsSync, readFileSync } from "node:fs";

export type FinalCoreProductFixture = {
  clientState: string;
  foreignClientState: string;
  providerState: string;
  messaging: { threadId: string; subject: string; message: string; foreignMarker: string };
  comparison: { requestId: string; rfqId: string; foreignMarker: string };
  matching: { requestId: string; policyVersion: string; minimumRuns: number };
  providerQualification: { organizationId: string; serviceId: string; serviceLabelFr: string };
};

const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/iu;
const safeText = (value: unknown, maximum = 200) => typeof value === "string" && value.length > 0 && value.length <= maximum && !/[\u0000-\u001f\u007f]/u.test(value);

export function loadFinalCoreProductFixture(): FinalCoreProductFixture | null {
  const path = process.env.E2E_FINAL_CORE_PRODUCT_MANIFEST;
  if (!path || !existsSync(path)) return null;
  try {
    const value = JSON.parse(readFileSync(path, "utf8")) as FinalCoreProductFixture & { schemaVersion?: number; environment?: string; expiresAt?: string };
    const expiry = Date.parse(value.expiresAt ?? "");
    if (value.schemaVersion !== 1 || value.environment !== "TEST" || !Number.isFinite(expiry) || expiry <= Date.now()
      || !existsSync(value.clientState) || !existsSync(value.foreignClientState) || !existsSync(value.providerState)
      || !uuid.test(value.messaging?.threadId) || !safeText(value.messaging?.subject) || !safeText(value.messaging?.message, 1_000) || !safeText(value.messaging?.foreignMarker)
      || !uuid.test(value.comparison?.requestId) || !uuid.test(value.comparison?.rfqId) || !safeText(value.comparison?.foreignMarker)) return null;
    if (!uuid.test(value.matching?.requestId) || !safeText(value.matching?.policyVersion, 80)
      || !Number.isInteger(value.matching?.minimumRuns) || value.matching.minimumRuns < 2 || value.matching.minimumRuns > 10) return null;
    if (!uuid.test(value.providerQualification?.organizationId) || !uuid.test(value.providerQualification?.serviceId)
      || !safeText(value.providerQualification?.serviceLabelFr, 240)) return null;
    return value;
  } catch {
    return null;
  }
}
