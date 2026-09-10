import { readFileSync } from "node:fs";

const query = process.argv.slice(2).join(" ").trim().toLowerCase();
if (!query) throw new Error("Indiquer un terme ou un identifiant ciblé.");
const source = readFileSync("Matricia_GOLD_MASTER_PROMPT_UNIQUE_CODEX_V4_FINAL_2026-09-10.md", "utf8").split(/\r?\n/);
const matches = source.flatMap((line, index) => line.toLowerCase().includes(query) ? source.slice(Math.max(0, index - 3), index + 5) : []);
console.log([...new Set(matches)].slice(0, 160).join("\n"));
