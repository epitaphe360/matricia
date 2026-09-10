import { createReadStream, readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { resolve } from "node:path";

const base = resolve("catalogue/Matricia_Catalogue_Metier_V1");
const manifest = JSON.parse(readFileSync(resolve(base, "catalog_manifest.json"), "utf8"));
const expected = { libraries: 10, categories: 40, subcategories: 80, services: 200, service_subcategory_links: 212, total_questions: 6000 };

for (const [key, value] of Object.entries(expected)) {
  if (manifest.counts?.[key] !== value) throw new Error(`Catalogue: ${key}=${manifest.counts?.[key]}, attendu=${value}`);
}

let lines = 0;
const ids = new Set<string>();
for await (const line of createInterface({ input: createReadStream(resolve(base, "questions_all.jsonl"), "utf8"), crlfDelay: Infinity })) {
  if (!line.trim()) continue;
  const record = JSON.parse(line) as { question_id?: string };
  if (!record.question_id || ids.has(record.question_id)) throw new Error("Catalogue: question invalide ou dupliquée");
  ids.add(record.question_id);
  lines += 1;
}
if (lines !== expected.total_questions) throw new Error(`Catalogue: ${lines} questions, attendu=${expected.total_questions}`);
console.log("Catalogue valide: 10 bibliothèques, 200 services, 6000 questions.");
