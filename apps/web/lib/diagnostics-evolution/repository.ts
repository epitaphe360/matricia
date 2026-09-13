import { z } from "zod";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { evolutionRatingSchema, exactScoreSchema, scoreToHundredths, type EvolutionPoint, type EvolutionResult } from "./model";

const uuid = z.string().uuid();
const membershipRow = z.object({ id: uuid, organization_id: uuid }).strict();
const roleRow = z.object({ membership_id: uuid, role_code: z.enum(["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_EDITOR", "CLIENT_VIEWER"]) }).strict();
const runRow = z.object({ id: uuid, organization_id: uuid, library_id: uuid, overall_score: z.union([z.string(), z.number()]), rating: evolutionRatingSchema, status: z.enum(["COMPLETED", "SUPERSEDED"]), completed_at: z.string().min(10) }).strict();
const anomalyRow = z.object({ diagnostic_run_id: uuid, severity: z.enum(["INFO", "WARNING", "HIGH", "CRITICAL"]), status: z.enum(["OPEN", "IGNORED", "RESOLVED"]) }).strict();
const libraryRow = z.object({ id: uuid, code: z.string().min(2).max(80) }).strict();
const clientRoles = ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_EDITOR", "CLIENT_VIEWER"] as const;

export async function loadDiagnosticsEvolution(): Promise<EvolutionResult> {
  const client = await getSupabaseServerClient();
  const { data: auth, error: authError } = await client.auth.getUser();
  if (authError || !auth.user) return { status: "error", reason: "UNAUTHENTICATED" };
  const membershipsQuery = await client.from("organization_memberships").select("id,organization_id").eq("user_id", auth.user.id).eq("status", "ACTIVE").limit(100);
  if (membershipsQuery.error) return { status: "error", reason: "UNAVAILABLE" };
  const memberships = z.array(membershipRow).max(100).safeParse(membershipsQuery.data);
  if (!memberships.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const membershipIds = memberships.data.map((membership) => membership.id);
  if (membershipIds.length === 0) return { status: "error", reason: "FORBIDDEN" };
  const rolesQuery = await client.from("organization_member_roles").select("membership_id,role_code").in("membership_id", membershipIds).is("revoked_at", null).in("role_code", [...clientRoles]).limit(400);
  if (rolesQuery.error) return { status: "error", reason: "UNAVAILABLE" };
  const roles = z.array(roleRow).max(400).safeParse(rolesQuery.data);
  if (!roles.success) return { status: "error", reason: "INVALID_RESPONSE" };
  const clientMembershipIds = new Set(roles.data.map((role) => role.membership_id));
  const organizationIds = [...new Set(memberships.data.filter((membership) => clientMembershipIds.has(membership.id)).map((membership) => membership.organization_id))];
  if (organizationIds.length === 0) return { status: "error", reason: "FORBIDDEN" };

  const runsQuery = await client.from("diagnostic_runs").select("id,organization_id,library_id,overall_score,rating,status,completed_at").in("organization_id", organizationIds).order("completed_at", { ascending: false }).limit(201);
  if (runsQuery.error) return { status: "error", reason: runsQuery.error.code === "42501" ? "FORBIDDEN" : "UNAVAILABLE" };
  const runs = z.array(runRow).max(201).safeParse(runsQuery.data);
  if (!runs.success || runs.data.some((run) => !organizationIds.includes(run.organization_id))) return { status: "error", reason: "INVALID_RESPONSE" };
  const visibleRuns = runs.data.slice(0, 200);
  const runIds = visibleRuns.map((run) => run.id);
  const libraryIds = [...new Set(visibleRuns.map((run) => run.library_id))];
  const [anomaliesQuery, librariesQuery] = await Promise.all([
    runIds.length === 0 ? Promise.resolve({ data: [], error: null }) : client.from("diagnostic_anomalies").select("diagnostic_run_id,severity,status").in("diagnostic_run_id", runIds).limit(2001),
    libraryIds.length === 0 ? Promise.resolve({ data: [], error: null }) : client.from("catalog_libraries").select("id,code").in("id", libraryIds).limit(11),
  ]);
  if (anomaliesQuery.error || librariesQuery.error) return { status: "error", reason: "UNAVAILABLE" };
  const anomalies = z.array(anomalyRow).max(2001).safeParse(anomaliesQuery.data);
  const libraries = z.array(libraryRow).max(11).safeParse(librariesQuery.data);
  if (!anomalies.success || !libraries.success || libraries.data.length > 10 || anomalies.data.some((anomaly) => !runIds.includes(anomaly.diagnostic_run_id))) return { status: "error", reason: "INVALID_RESPONSE" };
  const libraryCodes = new Map(libraries.data.map((library) => [library.id, library.code]));
  if (visibleRuns.some((run) => !libraryCodes.has(run.library_id))) return { status: "error", reason: "INVALID_RESPONSE" };
  const normalizedScores = new Map<string, string>();
  for (const run of visibleRuns) {
    const score = String(run.overall_score);
    if (!exactScoreSchema.safeParse(score).success) return { status: "error", reason: "INVALID_RESPONSE" };
    normalizedScores.set(run.id, score);
  }
  const anomalyCounts = new Map<string, { open: number; critical: number }>();
  for (const anomaly of anomalies.data.slice(0, 2000)) {
    const count = anomalyCounts.get(anomaly.diagnostic_run_id) ?? { open: 0, critical: 0 };
    if (anomaly.status === "OPEN") count.open += 1;
    if (anomaly.status === "OPEN" && anomaly.severity === "CRITICAL") count.critical += 1;
    anomalyCounts.set(anomaly.diagnostic_run_id, count);
  }
  const series = libraryIds.map((libraryId) => {
    const raw = visibleRuns.filter((run) => run.library_id === libraryId);
    const points: EvolutionPoint[] = raw.map((run, index) => {
      const score = normalizedScores.get(run.id)!;
      const scoreHundredths = scoreToHundredths(score);
      const older = raw[index + 1];
      const olderScore = older ? normalizedScores.get(older.id)! : null;
      const counts = anomalyCounts.get(run.id) ?? { open: 0, critical: 0 };
      return { id: run.id, libraryId, libraryCode: libraryCodes.get(libraryId)!, score, scoreHundredths, deltaHundredths: olderScore === null ? null : scoreHundredths - scoreToHundredths(olderScore), rating: run.rating, status: run.status, completedAt: run.completed_at, openAnomalies: counts.open, criticalAnomalies: counts.critical };
    });
    return { libraryId, libraryCode: libraryCodes.get(libraryId)!, points };
  }).sort((left, right) => left.libraryCode.localeCompare(right.libraryCode));
  return { status: "success", value: { series, truncated: runs.data.length > 200 || anomalies.data.length > 2000 } };
}
