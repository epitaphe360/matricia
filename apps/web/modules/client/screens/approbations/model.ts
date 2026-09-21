export type ClientApprovalRequest = {
  id: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  rowVersion: number;
  resourceType: string;
  resourceId: string;
  amountMinor: string | null;
  currency: string | null;
  requestedAt: string;
};
