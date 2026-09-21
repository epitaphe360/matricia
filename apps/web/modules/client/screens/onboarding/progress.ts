import type { ComplianceStatus } from "./actions";

export function onboardingProgressIndex(
  status: ComplianceStatus | null,
  trialStatus?: "TRIAL_ACTIVE" | "TRIAL_EXPIRED" | null,
) {
  if (!status) return -1;
  if (status === "VERIFIED" && trialStatus === "TRIAL_ACTIVE") return 4;
  if (status === "VERIFIED") return 3;
  if (status === "UNDER_REVIEW" || status === "QUESTION_REQUIRED" || status === "RESPONSE_RECEIVED") return 2;
  if (status === "DOCUMENTS_REQUIRED") return 1;
  return 0;
}
