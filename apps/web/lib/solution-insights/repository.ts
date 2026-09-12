import { z } from "zod";
import type { Result, SolutionFailure, SolutionInsightsRepository } from "./contracts";
import { explanationValue, solutionDecision, solutionLevel, solutionNarrative, uuid, type SolutionSet } from "./model";

type QueryError = { code?: string; message?: string };
type Query = { data: unknown; error: QueryError | null };
export type Source = { user(): Promise<string | null>; memberships(userId: string): Promise<Query>; roles(membershipIds: string[]): Promise<Query>; sets(): Promise<Query>; options(ids: string[]): Promise<Query>; decisions(ids: string[]): Promise<Query>; benchmarks(): Promise<Query>; rpc(name: string, input: Record<string, unknown>): Promise<Query> };

const setRow = z.object({ id: uuid, organization_id: uuid, anomaly_id: uuid, version: z.number().int().positive(), rationale_fr: z.string(), rationale_ar: z.string(), created_at: z.string() }).strict();
const membershipRow = z.object({ id: uuid, organization_id: uuid }).strict();
const roleRow = z.object({ membership_id: uuid, role_code: z.enum(["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER"]), revoked_at: z.string().nullable() }).strict();
const exactMinor = z.union([z.string().regex(/^\d+$/u), z.number().int().nonnegative().safe()]).transform(String);
const optionRow = z.object({ id: uuid, solution_set_id: uuid, level: solutionLevel, expected_score_bps: z.number().int().min(0).max(10_000), estimated_amount_minor: exactMinor.nullable(), currency: z.string().regex(/^[A-Z]{3}$/u).nullable(), benefits: z.array(solutionNarrative), tradeoffs: z.array(solutionNarrative), explanation: z.record(z.string(), explanationValue) }).strict();
const decisionRow = z.object({ id: uuid, solution_set_id: uuid, level: solutionLevel, decision: solutionDecision, reason: z.string(), deferred_until: z.string().nullable(), decided_at: z.string() }).strict();
const benchmarkRow = z.object({ id: uuid, metric_code: z.string(), segment_key: z.string(), period_start: z.string(), period_end: z.string(), group_size_band: z.string(), rounded_mean: z.union([z.string(), z.number().finite().safe()]).transform(String), published_at: z.string() }).strict();
const decisionResponse = z.object({ outcome: z.enum(["SOLUTION_ACCEPTED", "SOLUTION_REJECTED", "SOLUTION_DEFERRED"]), decision_id: uuid, solution_set_id: uuid, level: solutionLevel }).strict();

function failure(error: QueryError | null): SolutionFailure {
  const message = error?.message ?? "";
  if (error?.code === "42501" || message.includes("SOLUTION_DECISION_DENIED")) return "FORBIDDEN";
  if (error?.code === "40001" || message.includes("IDEMPOTENCY_")) return "CONFLICT";
  if (error?.code === "22023" || message.includes("INVALID_SOLUTION_DECISION")) return "INVALID_INPUT";
  return "UNAVAILABLE";
}
function rows<T>(schema: z.ZodType<T>, query: Query, max: number): Result<T[]> {
  if (query.error) return { status: "error", reason: failure(query.error) };
  const parsed = z.array(schema).max(max).safeParse(query.data);
  return parsed.success ? { status: "success", value: parsed.data } : { status: "error", reason: "INVALID_RESPONSE" };
}

export function createSolutionInsightsRepository(source: Source): SolutionInsightsRepository {
  return {
    async list() {
      const userId = await source.user();
      if (!userId) return { status: "error", reason: "UNAUTHENTICATED" };
      const memberships = rows(membershipRow, await source.memberships(userId), 100);
      if (memberships.status === "error") return memberships;
      const roles = rows(roleRow, await source.roles(memberships.value.map((item) => item.id)), 300);
      if (roles.status === "error") return roles;
      const organizationByMembership = new Map(memberships.value.map((item) => [item.id, item.organization_id]));
      const writableOrganizations = new Set(roles.value.filter((role) => role.revoked_at === null).map((role) => organizationByMembership.get(role.membership_id)).filter((organizationId): organizationId is string => Boolean(organizationId)));
      const [setsQuery, benchmarksQuery] = await Promise.all([source.sets(), source.benchmarks()]);
      const sets = rows(setRow, setsQuery, 100), benchmarks = rows(benchmarkRow, benchmarksQuery, 100);
      if (sets.status === "error") return sets;
      if (benchmarks.status === "error") return benchmarks;
      const ids = sets.value.map((item) => item.id);
      const [optionsQuery, decisionsQuery] = await Promise.all([source.options(ids), source.decisions(ids)]);
      const options = rows(optionRow, optionsQuery, 300), decisions = rows(decisionRow, decisionsQuery, 300);
      if (options.status === "error") return options;
      if (decisions.status === "error") return decisions;
      const value: SolutionSet[] = sets.value.map((set) => ({
        id: set.id, anomalyId: set.anomaly_id, canDecide: writableOrganizations.has(set.organization_id), version: set.version, rationaleFr: set.rationale_fr, rationaleAr: set.rationale_ar, createdAt: set.created_at,
        options: options.value.filter((option) => option.solution_set_id === set.id).map((option) => ({ id: option.id, level: option.level, expectedScoreBps: option.expected_score_bps, estimatedAmountMinor: option.estimated_amount_minor === null ? null : String(option.estimated_amount_minor), currency: option.currency, benefits: option.benefits, tradeoffs: option.tradeoffs, explanation: option.explanation })),
        decisions: decisions.value.filter((decision) => decision.solution_set_id === set.id).map((decision) => ({ id: decision.id, level: decision.level, decision: decision.decision, reason: decision.reason, deferredUntil: decision.deferred_until, decidedAt: decision.decided_at })),
      }));
      return { status: "success", value: { sets: value, benchmarks: benchmarks.value.map((item) => ({ id: item.id, metricCode: item.metric_code, segmentKey: item.segment_key, periodStart: item.period_start, periodEnd: item.period_end, groupSizeBand: item.group_size_band, roundedMean: String(item.rounded_mean), publishedAt: item.published_at })) } };
    },
    async decide(input) {
      if (!uuid.safeParse(input.solutionSetId).success || !solutionLevel.safeParse(input.level).success || !solutionDecision.safeParse(input.decision).success || input.reason.trim().length < 3 || !uuid.safeParse(input.correlationId).success || input.idempotencyKey.length < 8) return { status: "error", reason: "INVALID_INPUT" };
      if (!await source.user()) return { status: "error", reason: "UNAUTHENTICATED" };
      const query = await source.rpc("record_solution_decision", { p_solution_set_id: input.solutionSetId, p_level: input.level, p_decision: input.decision, p_reason: input.reason.trim(), p_deferred_until: input.deferredUntil, p_idempotency_key: input.idempotencyKey, p_correlation_id: input.correlationId });
      if (query.error) return { status: "error", reason: failure(query.error) };
      const parsed = decisionResponse.safeParse(query.data);
      return parsed.success ? { status: "success", value: { outcome: parsed.data.outcome, decisionId: parsed.data.decision_id, solutionSetId: parsed.data.solution_set_id, level: parsed.data.level } } : { status: "error", reason: "INVALID_RESPONSE" };
    },
  };
}
