import { randomUUID } from "node:crypto";
import type { MarketingDashboard } from "@/modules/shared/lib/marketing-autopilot/model";

export function marketingActionKeys(dashboard: MarketingDashboard | null): Record<string, string> {
  const keys: Record<string, string> = {
    consent: randomUUID(),
    campaign: randomUUID(),
    scheduleRule: randomUUID(),
    brandKit: randomUUID(),
    brandEvidenceReview: randomUUID(),
    templates: randomUUID(),
  };
  if (!dashboard) return keys;
  dashboard.campaigns.forEach((value) => {
    keys[`approve:${value.id}`] = randomUUID();
    keys[`schedule:${value.id}`] = randomUUID();
  });
  dashboard.scheduleRules.forEach((value) => {
    keys[`activateRule:${value.id}`] = randomUUID();
  });
  dashboard.calendars.forEach((value) => {
    keys[`approveCalendar:${value.id}`] = randomUUID();
  });
  return keys;
}
