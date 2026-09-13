import { createReadStream } from "node:fs";
import { readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { createInterface } from "node:readline";
import { resolve } from "node:path";

type FindingCode =
  | "DUPLICATE_QUESTION_ID"
  | "DUPLICATE_SEMANTIC_QUESTION"
  | "QUESTION_WITHOUT_SERVICE"
  | "BROKEN_JSON_RULE"
  | "ANOMALY_WITHOUT_RECOMMENDATION"
  | "RECOMMENDATION_WITHOUT_OPPORTUNITY"
  | "SERVICE_WITHOUT_QUOTE_FORM"
  | "ARABIC_TRANSLATION_MISSING"
  | "EXPERT_REVIEW_REQUIRED";

interface Finding {
  code: FindingCode;
  count: number;
  samples: string[];
}

interface AuditResult {
  status: "PASS" | "CONTENT_REVIEW_REQUIRED";
  catalogVersion: string;
  sourceManifestHash: string;
  counts: { services: number; questions: number };
  findings: Finding[];
}

function parseCsvLine(line: string): string[] {
  const cells: string[] = [];
  let cell = "";
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (character === '"') {
      if (quoted && line[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === "," && !quoted) {
      cells.push(cell);
      cell = "";
    } else {
      cell += character;
    }
  }
  if (quoted) throw new Error("UNTERMINATED_CSV_QUOTE");
  cells.push(cell);
  return cells;
}

async function scanCsv(path: string, consume: (row: Readonly<Record<string, string>>, line: number) => void): Promise<void> {
  const lines = createInterface({ input: createReadStream(path, { encoding: "utf8" }), crlfDelay: Number.POSITIVE_INFINITY });
  let headers: string[] | undefined;
  let lineNumber = 0;
  for await (const line of lines) {
    lineNumber += 1;
    if (line.trim() === "") continue;
    const values = parseCsvLine(line.replace(/^\uFEFF/, ""));
    if (!headers) {
      headers = values;
      continue;
    }
    if (values.length !== headers.length) throw new Error(`CSV_COLUMN_MISMATCH:${path}:${lineNumber}`);
    consume(Object.fromEntries(headers.map((header, index) => [header, values[index] ?? ""])), lineNumber);
  }
  if (!headers) throw new Error(`CSV_EMPTY:${path}`);
}

function counter() {
  const map = new Map<FindingCode, { count: number; samples: string[] }>();
  return {
    add(code: FindingCode, sample: string) {
      const current = map.get(code) ?? { count: 0, samples: [] };
      current.count += 1;
      if (current.samples.length < 10) current.samples.push(sample);
      map.set(code, current);
    },
    findings(): Finding[] {
      return [...map.entries()].map(([code, value]) => ({ code, ...value })).sort((left, right) => left.code.localeCompare(right.code));
    },
  };
}

export async function auditCatalogV41(directory: string): Promise<AuditResult> {
  const manifestText = await readFile(resolve(directory, "catalog_manifest.json"), "utf8");
  const manifest = JSON.parse(manifestText) as { catalog_version?: string; counts?: { services?: number; total_questions?: number } };
  const services = new Set<string>();
  const quoteServices = new Set<string>();
  const questionIds = new Set<string>();
  const semanticHashes = new Set<string>();
  const findings = counter();
  let questionCount = 0;

  await scanCsv(resolve(directory, "services.csv"), (row) => {
    if (row.code) services.add(row.code);
  });

  const questionFiles = ["questions_diagnostic.csv", "questions_rfq.csv", "questions_provider_qualification.csv"];
  for (const file of questionFiles) {
    await scanCsv(resolve(directory, file), (row, line) => {
      questionCount += 1;
      const identity = row.question_id || `${file}:${line}`;
      if (questionIds.has(identity)) findings.add("DUPLICATE_QUESTION_ID", identity);
      questionIds.add(identity);

      const semanticHash = createHash("sha256").update([row.phase, row.library_code, row.service_code, row.label_fr.trim().toLocaleLowerCase("fr")].join("|")).digest("hex");
      if (semanticHashes.has(semanticHash)) findings.add("DUPLICATE_SEMANTIC_QUESTION", identity);
      semanticHashes.add(semanticHash);

      if (row.service_code && !services.has(row.service_code)) findings.add("QUESTION_WITHOUT_SERVICE", identity);
      if (row.phase === "RFQ" && row.service_code && row.required_for_quote.toLowerCase() === "true") quoteServices.add(row.service_code);
      for (const field of ["options_json", "validation_json", "condition_json"] as const) {
        try { JSON.parse(row[field]); } catch { findings.add("BROKEN_JSON_RULE", `${identity}:${field}`); }
      }
      if (row.anomaly_code && !row.recommendation_code) findings.add("ANOMALY_WITHOUT_RECOMMENDATION", identity);
      if (row.recommendation_code && !row.opportunity_service_code) findings.add("RECOMMENDATION_WITHOUT_OPPORTUNITY", identity);
      if (!("label_ar" in row) || row.label_ar.trim() === "") findings.add("ARABIC_TRANSLATION_MISSING", identity);
      if (["ACC", "LEGAL", "INS", "QHSE"].includes(row.library_code)) findings.add("EXPERT_REVIEW_REQUIRED", identity);
    });
  }

  for (const service of services) if (!quoteServices.has(service)) findings.add("SERVICE_WITHOUT_QUOTE_FORM", service);
  if (manifest.counts?.services !== services.size) throw new Error(`MANIFEST_SERVICE_COUNT_MISMATCH:${services.size}`);
  if (manifest.counts?.total_questions !== questionCount) throw new Error(`MANIFEST_QUESTION_COUNT_MISMATCH:${questionCount}`);

  const resultFindings = findings.findings();
  return {
    status: resultFindings.length === 0 ? "PASS" : "CONTENT_REVIEW_REQUIRED",
    catalogVersion: manifest.catalog_version ?? "0.0.0",
    sourceManifestHash: createHash("sha256").update(manifestText).digest("hex"),
    counts: { services: services.size, questions: questionCount },
    findings: resultFindings,
  };
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath === resolve(new URL(import.meta.url).pathname.replace(/^\/(?:[A-Za-z]:)/, (match) => match.slice(1)))) {
  const directory = resolve(process.argv[2] ?? "catalogue/Matricia_Catalogue_Metier_V1");
  const result = await auditCatalogV41(directory);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (process.argv.includes("--persist")) {
    const endpoint = process.env.SUPABASE_URL;
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!endpoint || !serviceKey) throw new Error("SUPABASE_PERSIST_CONFIGURATION_MISSING");
    const response = await fetch(`${endpoint.replace(/\/$/, "")}/rest/v1/rpc/record_catalog_content_review_findings_v41`, {
      method: "POST",
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}`, "content-type": "application/json" },
      body: JSON.stringify({ p_catalog_version: result.catalogVersion, p_source_manifest_hash: result.sourceManifestHash, p_findings: result.findings, p_idempotency_key: `catalog-v41-${result.sourceManifestHash.slice(0, 40)}` }),
    });
    if (!response.ok) throw new Error(`CATALOG_FINDINGS_PERSIST_FAILED:${response.status}`);
    process.stdout.write("Catalogue findings persisted through governed RPC.\n");
  }
  if (process.argv.includes("--fail-on-review") && result.status === "CONTENT_REVIEW_REQUIRED") process.exitCode = 2;
}
