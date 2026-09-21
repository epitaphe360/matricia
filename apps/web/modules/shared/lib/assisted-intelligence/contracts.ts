export type AssistanceFailure =
  | "UNAUTHENTICATED"
  | "FORBIDDEN"
  | "INVALID_INPUT"
  | "CONFLICT"
  | "UNAVAILABLE";

export type AssistanceResult<T> =
  | { status: "success"; value: T }
  | { status: "error"; reason: AssistanceFailure };

export type AssistanceContext =
  | "CONTEXTUAL_ASSISTANT"
  | "PROFILE_CHANGE"
  | "NEED_TEXT"
  | "QUESTIONNAIRE_QUALITY"
  | "SIMILARITY_REVIEW";

export type SuggestionStatus = "PROPOSED" | "ACCEPTED" | "REJECTED";
export type SuggestionDecision = "ACCEPTED" | "REJECTED";

export type AssistanceOrganization = {
  id: string;
  name: string;
  canAnalyze: boolean;
  canDecide: boolean;
};

export type AssistanceModel = {
  id: string;
  version: number;
  algorithm: "TOKEN_OVERLAP_V1";
};

export type AssistanceRequest = {
  id: string;
  organizationId: string;
  context: AssistanceContext;
  status: "COMPLETED" | "FAILED";
  createdAt: string;
  inputExpiresAt: string | null;
  inputRedactedAt: string | null;
};

export type AssistanceSuggestion = {
  id: string;
  requestId: string;
  organizationId: string;
  kind: string;
  targetType: string;
  targetId: string | null;
  relatedTargetId: string | null;
  scoreBasisPoints: number;
  explanationCode: string;
  modelVersion: number;
  humanReviewRequired: true;
  evidence: Record<string, unknown>;
  proposedPayload: Record<string, unknown>;
  status: SuggestionStatus;
  createdAt: string;
  decidedAt: string | null;
};

export type AssistanceDecisionRecord = {
  id: string;
  suggestionId: string;
  decision: SuggestionDecision;
  rationale: string;
  decidedAt: string;
};

export type AssistanceCandidate = {
  id: string;
  organizationId: string;
  labelFr: string;
  labelAr: string;
  detail: string;
};

export type AssistanceDashboard = {
  organizations: AssistanceOrganization[];
  model: AssistanceModel | null;
  requests: AssistanceRequest[];
  suggestions: AssistanceSuggestion[];
  decisions: AssistanceDecisionRecord[];
  serviceCandidates: AssistanceCandidate[];
  questionCandidates: AssistanceCandidate[];
  anomalyCandidates: AssistanceCandidate[];
  reassessmentCandidates: AssistanceCandidate[];
};

export type AnalysisOutcome = {
  outcome: "ASSISTANCE_PROPOSED";
  requestId: string;
  suggestionCount: number;
  modelVersionId: string;
  humanConfirmationRequired: true;
};

export type SimilarityOutcome = {
  outcome: "ANOMALY_SIMILARITY_PROPOSED";
  requestId: string;
  suggestionCount: number;
  humanConfirmationRequired: true;
};

export type DecisionOutcome = {
  outcome: "ASSISTANCE_SUGGESTION_ACCEPTED" | "ASSISTANCE_SUGGESTION_REJECTED";
  suggestionId: string;
  decisionId: string;
  businessActionExecuted: false;
};

export interface AssistedIntelligenceRepository {
  dashboard(): Promise<AssistanceResult<AssistanceDashboard>>;
  analyze(input: {
    organizationId: string;
    context: AssistanceContext;
    inputText: string | null;
    serviceVersionIds: string[];
    questionVersionIds: string[];
    knownDataKeys: string[];
    modelVersionId: string;
    profileReassessmentId: string | null;
    idempotencyKey: string;
    correlationId: string;
  }): Promise<AssistanceResult<AnalysisOutcome>>;
  compareAnomalies(input: {
    organizationId: string;
    anomalyIds: string[];
    modelVersionId: string;
    idempotencyKey: string;
    correlationId: string;
  }): Promise<AssistanceResult<SimilarityOutcome>>;
  decide(input: {
    suggestionId: string;
    decision: SuggestionDecision;
    rationale: string;
    idempotencyKey: string;
    correlationId: string;
  }): Promise<AssistanceResult<DecisionOutcome>>;
}
