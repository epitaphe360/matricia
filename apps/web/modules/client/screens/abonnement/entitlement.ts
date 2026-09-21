export function canOpenNewRfq(subscriptionStatus: string | null | undefined) {
  if (!subscriptionStatus) return true;
  return subscriptionStatus === "TRIAL_ACTIVE" || subscriptionStatus === "ACTIVE";
}

export function newRequestBlockReason(input: {
  subscriptionStatus?: string | null;
  expiredDocumentCount: number;
}): "trial" | "document" | null {
  if (!canOpenNewRfq(input.subscriptionStatus)) return "trial";
  if (input.expiredDocumentCount > 0) return "document";
  return null;
}
