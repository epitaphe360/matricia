import { existsSync, readFileSync } from "node:fs";

type ContextIndex = {
  authority: string;
  indexes: Record<string, string>;
  domains: Record<string, string[]>;
};

const requirementId = (process.argv[2] ?? "").trim().toUpperCase();
if (!/^(?:MAT-FUNC-\d{3}|MARKETING-\d{3})$/.test(requirementId)) {
  throw new Error("Indiquer exactement un identifiant MAT-FUNC-NNN ou MARKETING-NNN.");
}

const read = (path: string): string => readFileSync(path, "utf8");
const index = JSON.parse(read("docs/specs/context-index.json")) as ContextIndex;
const domains = Object.entries(index.domains)
  .filter(([, requirements]) => requirements.includes(requirementId))
  .map(([domain]) => domain);
if (domains.length !== 1) throw new Error(`${requirementId} doit appartenir à un domaine unique.`);

const coverageLine = read(index.indexes.requirements)
  .split(/\r?\n/)
  .find((line) => line.startsWith(`| ${requirementId} |`));
if (!coverageLine) throw new Error(`Exigence inconnue: ${requirementId}`);
const cells = coverageLine.split("|").slice(1, -1).map((cell) => cell.trim());
const [id, status, implementationRefs, testRefs, evidence, owner, releaseSignoff] = cells;

const values = (content: string, key: string): string[] =>
  [...content.matchAll(new RegExp(`^\\s*-?\\s*${key}:\\s*(.+?)\\s*$`, "gm"))]
    .map((match) => match[1]!.trim().replace(/^\[/, "").replace(/\]$/, ""))
    .flatMap((value) => value.split(",").map((item) => item.trim().replace(/^["']|["']$/g, "")))
    .filter(Boolean);

const registry = Object.fromEntries(
  ["screens", "forms", "permissions", "apis", "events", "notifications", "state_machines"]
    .map((key) => [key, index.indexes[key]])
    .filter((entry): entry is [string, string] => typeof entry[1] === "string" && existsSync(entry[1])),
);
const screenText = read(registry.screens);
const formText = read(registry.forms);
const apiText = read(registry.apis);
const stateText = read(registry.state_machines);
const domain = domains[0]!;

const packet = {
  schema_version: 1,
  authority: index.authority,
  requirement: {
    id,
    status,
    owner,
    implementation_refs: implementationRefs,
    test_refs: testRefs,
    evidence,
    release_signoff: releaseSignoff,
  },
  domain,
  sources: {
    context_index: "docs/specs/context-index.json",
    requirements: index.indexes.requirements,
    section: domain === "identity" ? index.indexes.identity_rbac : domain === "marketing" ? index.indexes.marketing_autopilot : null,
    registries: registry,
  },
  contracts: {
    screens: domain === "identity" ? values(screenText, "screen_id").filter((value) => value.includes("ORG")) : [],
    forms: domain === "identity" ? values(formText, "form_id").filter((value) => value.includes("ORG")) : [],
    tables: domain === "identity" ? [...new Set(values(screenText, "data_sources"))] : [],
    apis: domain === "identity" ? values(apiText, "api_id").filter((value) => value.includes("ORG")) : [],
    transitions: domain === "identity" ? stateText.split(/\r?\n/).filter((line) => /^(organization|membership),/.test(line)).map((line) => line.split(",").slice(0, 4).join("→")) : [],
    tests: domain === "identity" ? [...new Set([...values(screenText, "test_cases"), ...values(formText, "tests"), ...values(apiText, "tests")])] : [],
  },
  catalog_rule: "Ne charger que la bibliothèque, le service ou le sous-ensemble requis; jamais les 6000 questions par défaut.",
};

console.log(JSON.stringify(packet, null, 2));
