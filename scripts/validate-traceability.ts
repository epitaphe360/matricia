import { existsSync, readFileSync } from "node:fs";

const content = readFileSync("docs/traceability/REQUIREMENTS_COVERAGE.md", "utf8");
const rows = content.split(/\r?\n/).filter((line) => /^\| (?:MAT-FUNC|MARKETING)-\d{3} \|/.test(line));
const parsed = rows.map((line) => line.split("|").slice(1, -1).map((cell) => cell.trim()));
const ids = parsed.map((cells) => cells[0]!);

function expected(prefix: string, count: number): string[] {
  return Array.from({ length: count }, (_, index) => `${prefix}-${String(index + 1).padStart(3, "0")}`);
}

const required = [...expected("MAT-FUNC", 68), ...expected("MARKETING", 8)];
const missing = required.filter((id) => !ids.includes(id));
const duplicates = [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))];
if (missing.length) throw new Error(`Traçabilité incomplète: ${missing.join(", ")}`);
if (duplicates.length) throw new Error(`Traçabilité dupliquée: ${duplicates.join(", ")}`);
if (ids.some((id) => /^MAT-FUNC-(?:069|07\d|08\d|090)$/.test(id))) {
  throw new Error("Des fonctions V2 figurent dans la couverture V1.");
}

for (const cells of parsed) {
  if (cells.length !== 7) throw new Error(`Colonnes de traçabilité invalides: ${cells[0] ?? "ligne inconnue"}`);
  const [id, status, implementationRefs, testRefs, evidence, owner, signoff] = cells;
  if (!["PLANNED", "IN_PROGRESS", "VERIFIED"].includes(status!)) throw new Error(`Statut invalide: ${id}`);
  if (!owner || !signoff) throw new Error(`Owner/signoff absent: ${id}`);
  if (status === "VERIFIED") {
    if ([implementationRefs, testRefs, evidence].some((value) => value === "[]")) throw new Error(`Preuves vides pour ${id}`);
    if (signoff === "PENDING") throw new Error(`Signoff absent pour ${id}`);
  }
  for (const raw of [implementationRefs, testRefs, evidence]) {
    if (raw === "[]") continue;
    const refs = raw!.replace(/^\[/, "").replace(/\]$/, "").split(",").map((value) => value.trim().replace(/^["']|["']$/g, ""));
    for (const ref of refs) {
      const path = ref.split("#")[0]!.replace(/:\d+$/, "");
      if (!existsSync(path)) throw new Error(`Référence inexistante pour ${id}: ${ref}`);
    }
  }
}

const verified = parsed.filter((cells) => cells[1] === "VERIFIED").length;
console.log(`Traçabilité cohérente pour 76 exigences V1; ${verified}/76 sont VERIFIED avec preuves contrôlées.`);
