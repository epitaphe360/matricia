import { formatExactScore, type DiagnosticDetail, type Opportunity } from "@/lib/diagnostics-opportunities/model";
import type { Locale } from "@/lib/i18n/locale";
import type { Messages } from "./messages";

export function DiagnosticSnapshot({ detail, locale, m }: { detail: DiagnosticDetail; locale: Locale; m: Messages }) {
  const policyVersion = textValue(detail.scoringPolicySnapshot.version);
  const policyHash = textValue(detail.scoringPolicySnapshot.content_hash);
  const formula = textValue(detail.explanation.formula);
  const questionnaireVersion = textValue(detail.explanation.questionnaire_version_id);
  return <section aria-labelledby="diagnostic-snapshot" className="rounded-xl border bg-card p-4 sm:p-5"><div className="flex flex-wrap items-start justify-between gap-3"><div><h2 id="diagnostic-snapshot" className="text-xl font-semibold">{m.snapshot}</h2><p className="mt-1 text-sm text-muted-foreground">{m.snapshotIntro}</p></div><span className="rounded-full border px-3 py-1 text-sm">{detail.status === "SUPERSEDED" ? m.superseded : m.current}</span></div><dl className="mt-4 grid min-w-0 gap-3 text-sm sm:grid-cols-2"><Datum label={m.session} value={detail.sessionId} mono/><Datum label={m.library} value={detail.libraryId} mono/><Datum label={m.inputManifest} value={detail.inputManifestHash} mono/><Datum label={m.policyVersion} value={policyVersion}/><Datum label={m.policyHash} value={policyHash} mono/><Datum label={m.questionnaireVersion} value={questionnaireVersion} mono/><Datum label={m.formula} value={formula}/><Datum label={m.completedAt} value={new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short" }).format(new Date(detail.completedAt))}/></dl></section>;
}

export function SubscoreExplanation({ subscore, m }: { subscore: DiagnosticDetail["subscores"][number]; m: Messages }) {
  return <div><strong dir="ltr">{formatExactScore(subscore.score)}/100</strong><dl className="mt-2 grid gap-2 text-sm"><Datum label={m.weightedPoints} value={subscore.weightedPoints}/><Datum label={m.maximumPoints} value={subscore.maximumPoints}/><Datum label={m.explanation} value={summarize(subscore.explanation)}/></dl></div>;
}

export function FindingExplanation({ anomaly, m }: { anomaly: DiagnosticDetail["anomalies"][number]; m: Messages }) {
  return <dl className="mt-3 grid gap-2 text-sm sm:grid-cols-2"><Datum label={m.anomalyCode} value={anomaly.code}/><Datum label={m.findingStatus} value={anomaly.status}/><Datum label={m.explanation} value={summarize(anomaly.explanation)}/><Datum label={m.ruleSnapshot} value={summarize(anomaly.ruleSnapshot)}/></dl>;
}

export function OpportunityContext({ opportunity, detail, locale, m }: { opportunity: Opportunity; detail: DiagnosticDetail; locale: Locale; m: Messages }) {
  const anomaly = detail.anomalies.find((value) => value.id === opportunity.anomalyId), recommendation = detail.recommendations.find((value) => value.id === opportunity.recommendationId), serviceName = locale === "ar" ? opportunity.serviceNameAr : opportunity.serviceNameFr;
  return <div className="space-y-3"><p className="font-medium">{m.whyOpportunity}: {anomaly ? locale === "ar" ? anomaly.titleAr : anomaly.titleFr : m.linkedFinding}</p>{recommendation ? <p className="text-sm">{locale === "ar" ? recommendation.textAr : recommendation.textFr}</p> : null}<dl className="grid gap-2 text-sm sm:grid-cols-2"><Datum label={m.solutionLevel} value={opportunity.solutionLevel}/><Datum label={m.service} value={serviceName ?? opportunity.serviceId ?? m.serviceUnavailable}/><Datum label={m.knownData} value={summarize(opportunity.knownData)}/><Datum label={m.missingFields} value={opportunity.missingFields.length ? opportunity.missingFields.map(String).join(", ") : m.none}/>{opportunity.serviceRequestId ? <Datum label={m.createdRequest} value={opportunity.serviceRequestId} mono/> : null}</dl><p className="rounded-lg border border-primary/30 bg-primary/5 p-3 text-sm">{m.humanDecision}</p></div>;
}

function Datum({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) { return <div className="min-w-0"><dt className="text-muted-foreground">{label}</dt><dd className={mono ? "mt-1 break-all font-mono text-xs" : "mt-1 break-words font-medium"} dir={mono ? "ltr" : "auto"}>{value || "—"}</dd></div>; }
function summarize(value: Record<string, unknown>) { const entries = Object.entries(value); return entries.length ? entries.map(([key, item]) => `${key}: ${textValue(item)}`).join(" · ") : "—"; }
function textValue(value: unknown) { if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return String(value); if (value === null || value === undefined) return "—"; return JSON.stringify(value); }
