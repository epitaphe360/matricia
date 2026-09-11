import { existsSync, readFileSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";

const required = [
  "AGENTS.md", "PLANS.md", "docs/inventory/PHASE00_INVENTORY.md",
  "docs/architecture/ARCHITECTURE.md", "docs/specs/context-index.json",
  "docs/specs/sections/phase-map.md", "docs/specs/sections/identity-rbac.md",
  "docs/specs/sections/marketing-autopilot.md", "docs/security/THREAT_MODEL.md",
  "docs/orchestration/FILE_OWNERSHIP.md", "docs/orchestration/file-ownership-map.csv",
  "docs/progress/PROJECT_STATE.md", "docs/progress/phase-ledger.json",
  "docs/traceability/REQUIREMENTS_COVERAGE.md", "docs/specs/registries/screens.yaml",
  "docs/specs/registries/forms.yaml", "docs/specs/registries/permissions.csv",
  "docs/specs/registries/apis.yaml", "docs/specs/registries/events.yaml",
  "docs/specs/registries/notifications.yaml", "docs/specs/registries/state-machines.csv",
];

function fail(message: string): never {
  throw new Error(message);
}

function read(path: string): string {
  return readFileSync(path, "utf8");
}

function values(content: string, key: string): string[] {
  const pattern = new RegExp(`^\\s*-?\\s*${key}:\\s*(.+?)\\s*$`, "gm");
  return [...content.matchAll(pattern)].map((match) => match[1]!.trim().replace(/^["']|["']$/g, ""));
}

function listValues(content: string, key: string): string[] {
  return values(content, key).flatMap((raw) => {
    const value = raw.replace(/^\[/, "").replace(/\]$/, "").trim();
    return value ? value.split(",").map((item) => item.trim().replace(/^["']|["']$/g, "")).filter(Boolean) : [];
  });
}

function parseCsv(content: string): Record<string, string>[] {
  const rows = content.trim().split(/\r?\n/).map((line) => {
    const cells: string[] = [];
    let current = "";
    let quoted = false;
    for (let index = 0; index < line.length; index += 1) {
      const char = line[index]!;
      if (char === '"') {
        if (quoted && line[index + 1] === '"') { current += '"'; index += 1; }
        else quoted = !quoted;
      } else if (char === "," && !quoted) { cells.push(current.trim()); current = ""; }
      else current += char;
    }
    cells.push(current.trim());
    return cells;
  });
  const headers = rows.shift() ?? [];
  return rows.map((cells) => Object.fromEntries(headers.map((header, index) => [header, cells[index] ?? ""])));
}

function assertKnown(kind: string, refs: string[], known: Set<string>): void {
  const unknown = [...new Set(refs)].filter((ref) => ref && ref !== "none" && !known.has(ref));
  if (unknown.length) fail(`${kind} inconnus: ${unknown.join(", ")}`);
}

const missing = required.filter((path) => !existsSync(path));
if (missing.length) fail(`Spécifications manquantes: ${missing.join(", ")}`);

const context = JSON.parse(read("docs/specs/context-index.json")) as {
  schema_version?: number;
  authority?: string;
  v1_scope?: Record<string, string>;
  indexes?: Record<string, string>;
  domains?: Record<string, string[]>;
  evidence_roots?: string[];
};
if (context.schema_version !== 2 || context.authority !== "Matricia_GOLD_MASTER_PROMPT_UNIQUE_CODEX_V4_FINAL_2026-09-10.md") {
  fail("Autorité ou version de l’index de contexte invalide.");
}
if (context.v1_scope?.required_functions !== "MAT-FUNC-001..MAT-FUNC-068" ||
    context.v1_scope?.excluded_functions !== "MAT-FUNC-069..MAT-FUNC-090" ||
    context.v1_scope?.required_addendum !== "MARKETING-001..MARKETING-008") {
  fail("Périmètre V1 de l’index invalide.");
}
const missingIndexes = Object.entries(context.indexes ?? {})
  .filter(([, path]) => !existsSync(path))
  .map(([key, path]) => `${key}=${path}`);
if (missingIndexes.length) fail(`Index de contexte invalides: ${missingIndexes.join(", ")}`);
const requiredIndexKeys = ["agent_rules", "skills", "custom_agents", "inventory", "phases", "identity_rbac", "marketing_autopilot", "requirements", "architecture", "threat_model", "ownership_rules", "ownership_map", "plans", "progress", "phase_ledger", "screens", "forms", "permissions", "apis", "events", "notifications", "state_machines"];
if (Object.keys(context.indexes ?? {}).sort().join("|") !== [...requiredIndexKeys].sort().join("|")) fail("Clés de l’index de contexte inexactes.");
for (const root of context.evidence_roots ?? []) if (!existsSync(root)) fail(`Racine de preuve absente: ${root}`);

const expectedRequirements = [
  ...Array.from({ length: 68 }, (_, index) => `MAT-FUNC-${String(index + 1).padStart(3, "0")}`),
  ...Array.from({ length: 8 }, (_, index) => `MARKETING-${String(index + 1).padStart(3, "0")}`),
];
const indexedRequirements = Object.values(context.domains ?? {}).flat();
if (indexedRequirements.length !== 76 || new Set(indexedRequirements).size !== 76 ||
    [...expectedRequirements].sort().join("|") !== [...indexedRequirements].sort().join("|")) {
  fail("L’index doit attribuer exactement une fois les 76 exigences V1, sans fonction V2.");
}
JSON.parse(read("docs/progress/phase-ledger.json"));

const registryPaths = required.filter((path) => path.includes("/registries/"));
const forbidden = /\b(?:TO_DEFINE|TO_IMPLEMENT|TBD|TODO|FIXME|PLACEHOLDER|UNKNOWN|NOT_STARTED)\b/g;
for (const path of registryPaths) {
  const content = read(path);
  const markers = [...content.matchAll(forbidden)].map((match) => match[0]);
  if (markers.length) fail(`Marqueurs interdits dans ${path}: ${[...new Set(markers)].join(", ")}`);
  if (content.trim().split(/\r?\n/).length < 2) fail(`Registre vide: ${path}`);
}

const screens = read("docs/specs/registries/screens.yaml");
const forms = read("docs/specs/registries/forms.yaml");
const apis = read("docs/specs/registries/apis.yaml");
const events = read("docs/specs/registries/events.yaml");
const notifications = read("docs/specs/registries/notifications.yaml");
const permissions = parseCsv(read("docs/specs/registries/permissions.csv"));
const machines = parseCsv(read("docs/specs/registries/state-machines.csv"));

const screenIds = new Set(values(screens, "screen_id"));
const formIds = new Set(values(forms, "form_id"));
const permissionIds = new Set(permissions.map((row) => row.permission_id!));
const eventTypes = new Set(values(events, "event_type"));
const notificationIds = new Set(values(notifications, "notification_id"));

assertKnown("Formulaires écran", listValues(screens, "forms"), formIds);
assertKnown("Permissions écran", listValues(screens, "permissions"), permissionIds);
assertKnown("Événements écran", listValues(screens, "events"), eventTypes);
assertKnown("Écrans formulaire", values(forms, "screen_id"), screenIds);
assertKnown("Événements API", listValues(apis, "outbox_events"), eventTypes);
assertKnown("Événements notification", values(notifications, "event"), eventTypes);
assertKnown("Événements state machine", machines.flatMap((row) => row.events!.split("|")), eventTypes);
assertKnown("Notifications state machine", machines.flatMap((row) => row.notifications!.split("|")), notificationIds);

const missingEvidence = values(screens, "evidence").filter((path) => !existsSync(path));
if (missingEvidence.length) fail(`Preuves écran manquantes: ${missingEvidence.join(", ")}`);

const coverage = read("docs/traceability/REQUIREMENTS_COVERAGE.md");
for (let index = 1; index <= 68; index += 1) {
  const id = `MAT-FUNC-${String(index).padStart(3, "0")}`;
  if (!coverage.includes(`| ${id} |`)) fail(`Traçabilité manquante: ${id}`);
}
for (let index = 1; index <= 8; index += 1) {
  const id = `MARKETING-${String(index).padStart(3, "0")}`;
  if (!coverage.includes(`| ${id} |`)) fail(`Traçabilité manquante: ${id}`);
}

const mandatoryAgents = [
  "program_orchestrator","repo_explorer","requirements_architect","chief_architect","domain_modeler",
  "database_architect","api_contract_architect","event_workflow_architect","auth_identity_agent",
  "rbac_rls_agent","security_architect","security_red_team","privacy_data_agent","client_onboarding_agent",
  "provider_onboarding_agent","provider_qualification_agent","franchise_governance_agent","library_catalog_agent",
  "question_engine_agent","diagnostics_agent","rfq_matching_agent","quote_agent","contract_mission_agent",
  "dispute_agent","subscription_agent","boxes_credits_agent","payments_agent","provider_finance_agent",
  "franchise_finance_agent","volume_procurement_agent","admin_command_center_agent","notifications_agent",
  "ux_information_architect","luxury_design_system_agent","frontend_client_agent","frontend_provider_agent",
  "frontend_franchise_agent","frontend_admin_agent","i18n_rtl_accessibility_agent","demo_data_agent",
  "domain_content_agent","arabic_content_reviewer","unit_integration_test_agent","database_rls_test_agent",
  "browser_e2e_agent","accessibility_qa_agent","performance_agent","observability_agent","code_quality_reviewer",
  "financial_integrity_auditor","requirements_traceability_auditor","integration_manager","release_manager",
  "documentation_curator","morocco_tax_compliance_agent","franchise_performance_auditor","billing_automation_auditor",
  "marketing-automation-agent","marketing-content-agent","marketing-compliance-agent",
  "social-integration-agent","marketing-analytics-agent","marketing-autopilot-auditor",
];
const configuredAgents = new Set(readdirSync(".codex/agents").filter((name) => name.endsWith(".toml")).map((name) => name.slice(0, -5)));
if (configuredAgents.size !== mandatoryAgents.length) fail(`Nombre de configurations agent invalide: ${configuredAgents.size}/63.`);
assertKnown("Configurations agent obligatoires", mandatoryAgents, configuredAgents);
for (const agent of mandatoryAgents) {
  const toml = read(`.codex/agents/${agent}.toml`);
  const parsed = toml.match(/^name = "([^"\r\n]+)"\r?\ndescription = "([^"\r\n]+)"\r?\ndeveloper_instructions = """\r?\n([\s\S]+?)\r?\n"""\r?\n?$/);
  if (!parsed) fail(`TOML agent non conforme au schéma strict: ${agent}.toml`);
  if (parsed[1] !== agent) fail(`Le nom interne ne correspond pas au fichier: ${agent}.toml`);
  if (parsed[2]!.trim().length < 20 || parsed[3]!.trim().length < 80) fail(`Description/instructions trop courtes: ${agent}.toml`);
}

const baseline = "d9e28f7";
const tree = execFileSync("git", ["ls-tree", "-r", "--name-only", baseline], { encoding: "utf8" }).trim().split(/\r?\n/);
const metrics = {
  total: tree.length,
  apps: tree.filter((path) => path.startsWith("apps/")).length,
  web: tree.filter((path) => path.startsWith("apps/web/")).length,
  worker: tree.filter((path) => path.startsWith("apps/worker/")).length,
  packages: tree.filter((path) => path.startsWith("packages/")).length,
  agents: tree.filter((path) => /^\.codex\/agents\/[^/]+\.toml$/.test(path)).length,
  skills: tree.filter((path) => /^\.agents\/skills\/[^/]+\/SKILL\.md$/.test(path)).length,
  migrations: tree.filter((path) => /^supabase\/migrations\/[^/]+\.sql$/.test(path)).length,
  dbTests: tree.filter((path) => /^supabase\/tests\/[^/]+\.sql$/.test(path)).length,
};
const expectedMetrics = { total: 300, apps: 95, web: 92, worker: 3, packages: 23, agents: 63, skills: 23, migrations: 13, dbTests: 6 };
if (JSON.stringify(metrics) !== JSON.stringify(expectedMetrics)) fail(`Métriques Git de baseline inattendues: ${JSON.stringify(metrics)}`);
const inventory = read("docs/inventory/PHASE00_INVENTORY.md");
for (const value of ["`d9e28f7`", "300 fichiers Git", "95 fichiers sous `apps/`", "92 Web", "3 Worker", "23 sous `packages/`", "63 configurations TOML", "23 skills", "13 migrations et 6 suites SQL"]) {
  if (!inventory.includes(value)) fail(`Inventaire sans métrique prouvée: ${value}`);
}

const plan = read("PLANS.md");
const planFields = ["id", "title", "status", "goal", "scope", "requirements", "invariants", "ownership", "dependencies", "milestones", "decisions", "risks", "validation_commands", "evidence_paths", "progress_log", "results", "independent_signoff", "next_phase"];
for (const phase of ["P00", "P01", "P02", "P03", "P04"]) {
  const block = plan.match(new RegExp(`id: ${phase}\\r?\\n([\\s\\S]*?)(?:\\r?\\n---|\\r?\\n\`\`\`)`))?.[0];
  if (!block) fail(`ExecPlan absent: ${phase}`);
  for (const field of planFields) if (!new RegExp(`^${field}:`, "m").test(block)) fail(`Champ ${field} absent de l’ExecPlan ${phase}`);
}

const marketingSpec = read("docs/specs/sections/marketing-autopilot.md");
const marketingAuthority = new Map([
  ["MARKETING-001", "Brand Kit automatisé"], ["MARKETING-002", "1 service = 3 contenus"],
  ["MARKETING-003", "Six templates standardisés"], ["MARKETING-004", "Calendrier mensuel automatique"],
  ["MARKETING-005", "Publication sociale contrôlée"], ["MARKETING-006", "Tracking CTA → contrat"],
  ["MARKETING-007", "Campagnes depuis anomalies réelles"], ["MARKETING-008", "Dashboard actionnable"],
]);
for (const [id, name] of marketingAuthority) if (!new RegExp(`\\| ${id} \\| \\*\\*${name.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&")}\\*\\*`).test(marketingSpec)) fail(`Mapping Marketing invalide: ${id}`);
for (const term of ["MANUAL", "ASSISTED", "AUTOPILOT", "LinkedIn", "Facebook/Instagram", "Reel 20–30 s", "PROBLEM_SOLUTION", "EXPERT_TIP", "PROVIDER_INTRO", "BEFORE_AFTER", "SERVICE_OF_MONTH", "SUCCESS_CASE", "8 posts + 4 Reels", "social_provider", "OAuth serveur", "LAST_NON_DIRECT_CLICK", "k-anonymity", "KEEP/INCREASE/REDUCE/CHANGE/PAUSE", "GENERATE → SOURCE_CHECK → BRAND_CHECK → CLAIMS_CHECK → PRIVACY_CHECK → CERTIFICATION_CHECK → DUPLICATE_CHECK → RISK_SCORE → SCHEDULE/PUBLISH"]) {
  if (!marketingSpec.includes(term)) fail(`Obligation Marketing absente: ${term}`);
}

const contextPacket = JSON.parse(execFileSync(process.execPath, ["--experimental-strip-types", "scripts/context-pack.ts", "MAT-FUNC-001"], { encoding: "utf8" })) as Record<string, unknown>;
for (const key of ["schema_version", "authority", "requirement", "domain", "sources", "contracts", "catalog_rule"]) if (!(key in contextPacket)) fail(`Paquet de contexte incomplet: ${key}`);
if (contextPacket.domain !== "identity" || (contextPacket.requirement as { id?: string }).id !== "MAT-FUNC-001") fail("Paquet de contexte non ciblé.");

console.log(`Bootstrap PHASE 00 cohérent: ${registryPaths.length} registres initialisés, 68 fonctions, 8 exigences marketing et ${mandatoryAgents.length} agents. P01 reste ouverte jusqu’aux contrats atomiques exhaustifs.`);
