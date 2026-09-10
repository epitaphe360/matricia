import { readFileSync } from "node:fs";

const content = readFileSync("docs/traceability/REQUIREMENTS_COVERAGE.md", "utf8");
const ids = [...content.matchAll(/^\| MAT-FUNC-(\d{3}) \|/gm)].map((match) => Number(match[1]));
const unique = new Set(ids.filter((id) => id >= 1 && id <= 68));
const missing = Array.from({ length: 68 }, (_, index) => index + 1).filter((id) => !unique.has(id));
if (missing.length) throw new Error(`Traçabilité incomplète: ${missing.map((id) => String(id).padStart(3, "0")).join(", ")}`);
if (ids.some((id) => id >= 69 && id <= 90)) throw new Error("Des fonctions V2 figurent dans la couverture V1.");
console.log("Traçabilité initialisée pour MAT-FUNC-001..068.");
