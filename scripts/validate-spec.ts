import { existsSync, readFileSync } from "node:fs";

const required = [
  "AGENTS.md", "PLANS.md", "docs/architecture/ARCHITECTURE.md", "docs/specs/context-index.json",
  "docs/specs/sections/phase-map.md", "docs/security/THREAT_MODEL.md", "docs/orchestration/FILE_OWNERSHIP.md",
  "docs/progress/PROJECT_STATE.md", "docs/progress/phase-ledger.json", "docs/traceability/REQUIREMENTS_COVERAGE.md",
  "docs/specs/registries/screens.yaml", "docs/specs/registries/forms.yaml",
  "docs/specs/registries/permissions.csv", "docs/specs/registries/apis.yaml",
  "docs/specs/registries/events.yaml", "docs/specs/registries/notifications.yaml",
  "docs/specs/registries/state-machines.csv",
];
const missing = required.filter((path) => !existsSync(path));
if (missing.length) throw new Error(`Spécifications manquantes: ${missing.join(", ")}`);
JSON.parse(readFileSync("docs/specs/context-index.json", "utf8"));
JSON.parse(readFileSync("docs/progress/phase-ledger.json", "utf8"));
const registryPaths = required.filter((path) => path.includes("/registries/"));
const forbidden = /\b(?:TO_DEFINE|TO_IMPLEMENT|TBD|TODO|FIXME|PLACEHOLDER|UNKNOWN|NOT_STARTED)\b/g;
for (const path of registryPaths) {
  const content = readFileSync(path, "utf8");
  const markers = [...content.matchAll(forbidden)].map((match) => match[0]);
  if (markers.length) throw new Error(`Marqueurs interdits dans ${path}: ${[...new Set(markers)].join(", ")}`);
  if (content.trim().split(/\r?\n/).length < 2) throw new Error(`Registre vide: ${path}`);
}
console.log(`Spécifications Phase 00 valides: ${registryPaths.length} registres initialisés.`);
