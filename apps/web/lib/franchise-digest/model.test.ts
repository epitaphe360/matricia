import { describe, expect, it } from "vitest";
import { digestConfigurationInput, formatBasisPoints, latestConfigurations } from "./model";

const id = "11111111-1111-4111-8111-111111111111";
describe("franchise digest contracts", () => {
  it("validates a bounded bilingual self-recipient configuration", () => expect(digestConfigurationInput.safeParse({ franchiseId: id, recipientUserId: id, enabled: true, frequency: "WEEKDAYS", localSendTime: "08:30", timeZone: "Africa/Casablanca", notificationLocale: "ar-MA", changeReason: "تحديث التوقيت", idempotencyKey: id }).success).toBe(true));
  it("rejects invalid frequency, time, locale and reason", () => expect(digestConfigurationInput.safeParse({ franchiseId: id, recipientUserId: id, enabled: true, frequency: "WEEKLY", localSendTime: "25:80", timeZone: "", notificationLocale: "en-US", changeReason: "x", idempotencyKey: id }).success).toBe(false));
  it("keeps only the latest version per franchise", () => { const base = { id, franchise_id: id, recipient_user_id: id, enabled: true, frequency: "DAILY" as const, local_send_time: "08:00:00", time_zone: "Africa/Casablanca", locale: "fr-MA" as const, created_at: "2026-09-12T00:00:00Z" }; expect(latestConfigurations([{ ...base, version: 2 }, { ...base, id: "22222222-2222-4222-8222-222222222222", version: 1 }])[0]?.version).toBe(2); });
  it("formats basis points without floating business arithmetic", () => expect(formatBasisPoints(5050, "fr")).toContain("50,5"));
});
