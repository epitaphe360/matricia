import { readdirSync, readFileSync, statSync } from "node:fs";
import { extname, join } from "node:path";

const roots = ["apps/web/app", "apps/worker", "packages", "supabase", "tests"].filter((path) => {
  try { return statSync(path).isDirectory(); } catch { return false; }
});
const extensions = new Set([".ts", ".tsx", ".sql"]);
const forbidden = /\b(?:TODO|FIXME|TBD)\b|(?<![A-Za-z0-9_$])PLACEHOLDER(?![A-Za-z0-9_$=])/i;
const violations: string[] = [];

function visit(path: string) {
  for (const entry of readdirSync(path)) {
    if (["node_modules", "dist", ".next", ".vinext", "coverage"].includes(entry)) continue;
    const target = join(path, entry);
    if (statSync(target).isDirectory()) visit(target);
    else if (extensions.has(extname(target)) && forbidden.test(readFileSync(target, "utf8"))) violations.push(target);
  }
}
roots.forEach(visit);
if (violations.length) throw new Error(`Marqueurs interdits: ${violations.join(", ")}`);
console.log("Aucun marqueur incomplet dans le périmètre applicatif.");
