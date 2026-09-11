import { existsSync, readFileSync, readdirSync } from "node:fs";

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

const context = JSON.parse(read("docs/specs/context-index.json")) as { indexes?: Record<string, string> };
const missingIndexes = Object.entries(context.indexes ?? {})
  .filter(([, path]) => !existsSync(path))
  .map(([key, path]) => `${key}=${path}`);
if (missingIndexes.length) fail(`Index de contexte invalides: ${missingIndexes.join(", ")}`);
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
assertKnown("Configurations agent obligatoires", mandatoryAgents, configuredAgents);
for (const agent of mandatoryAgents) {
  const toml = read(`.codex/agents/${agent}.toml`);
  for (const field of ["name", "description", "developer_instructions"]) {
    if (!new RegExp(`^${field}\\s*=`, "m").test(toml)) fail(`Champ ${field} manquant: ${agent}.toml`);
  }
}

const marketingSpec = read("docs/specs/sections/marketing-autopilot.md");
const marketingAuthorityTerms = [
  "Brand Kit automatisé", "1 service = 3 contenus", "Six templates standardisés",
  "Calendrier mensuel automatique", "Publication sociale contrôlée",
  "Tracking CTA → contrat", "Campagnes depuis anomalies réelles", "Dashboard actionnable",
];
for (const term of marketingAuthorityTerms) {
  if (!marketingSpec.includes(term)) fail(`Contrat Marketing non conforme à l’autorité: ${term}`);
}

console.log(`Bootstrap PHASE 00 cohérent: ${registryPaths.length} registres initialisés, 68 fonctions, 8 exigences marketing et ${mandatoryAgents.length} agents. P01 reste ouverte jusqu’aux contrats atomiques exhaustifs.`);
