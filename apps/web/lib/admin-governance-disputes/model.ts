import type { FranchiseDashboard } from "@/lib/franchise-governance/model";

export type AdminGovernanceCapabilities = {
  governance: boolean;
  finance: boolean;
  disputes: boolean;
  canApproveGovernance: boolean;
  fourEyesRequired: true;
};

export type ApprovalSeparation = {
  approvalRequestId: string;
  hasDecision: boolean;
  independentReviewer: boolean | null;
};

export type AdminDisputeSummary = {
  id: string;
  missionId: string;
  obligationKey: string;
  urgency: "STANDARD" | "URGENT";
  status: string;
  policyVersion: string;
  responseDueAt: string;
  reviewDueAt: string | null;
  latestDecision: null | {
    number: number;
    outcome: string;
    reason: string;
    evidenceCount: number;
    ruleVersion: string;
    decidedAt: string;
    independentReviewer: boolean;
  };
  reassignment: null | {
    key: string;
    status: string;
    originalCostMinor: string;
    proposedCostMinor: string | null;
    costDeltaMinor: string | null;
    currency: string;
    clientCostApproved: boolean;
    replacementContractId: string | null;
    replacementMissionId: string | null;
  };
  consequences: Array<{ type: string; direction: "ACCRUAL" | "REVERSAL"; amountMinor: string; currency: string }>;
};

export type AdminGovernanceDashboard = {
  capabilities: AdminGovernanceCapabilities;
  franchise: FranchiseDashboard | null;
  approvalSeparation: ApprovalSeparation[];
  disputes: AdminDisputeSummary[];
};

export type AdminGovernanceResult =
  | { status: "success"; value: AdminGovernanceDashboard }
  | { status: "error"; reason: "UNAUTHENTICATED" | "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE" };
