import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, extname, join, relative, resolve } from "node:path";

type PackageManifest = Readonly<{
  name?: string;
  scripts?: Readonly<Record<string, string>>;
}>;

const REQUIRED_SCRIPTS = ["lint", "typecheck", "test", "build"] as const;
const INTERNAL_PREFIX = "@matricia/";
const packagesRoot = "packages";

const allowedInternalDependencies: Readonly<Record<string, ReadonlySet<string>>> = {
  application: new Set(["config", "contracts", "domain", "observability", "workflows"]),
  config: new Set(),
  contracts: new Set(["domain"]),
  domain: new Set(),
  forms: new Set(["config", "contracts", "ui", "workflows"]),
  infrastructure: new Set(["application", "config", "contracts", "domain", "observability", "workflows"]),
  observability: new Set(["config"]),
  testkit: new Set(["application", "config", "contracts", "domain", "forms", "infrastructure", "observability", "ui", "workflows"]),
  ui: new Set(["config", "contracts"]),
  workflows: new Set(["contracts", "domain"]),
};

const frameworkIndependentPackages = new Set(["application", "contracts", "domain", "workflows"]);
const frameworkImports = ["next", "react", "react-dom", "@supabase/"] as const;
const importPattern = /(?:from\s*|import\s*(?:\(\s*)?|require\s*\(\s*)["']([^"']+)["']/g;
const sourceExtensions = new Set([".ts", ".tsx", ".mts", ".cts"]);
const violations: string[] = [];

function parseJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function sourceFiles(root: string): string[] {
  if (!statSync(root).isDirectory()) return [];
  return readdirSync(root, { withFileTypes: true }).flatMap((entry) => {
    const path = join(root, entry.name);
    if (entry.isDirectory()) return sourceFiles(path);
    return sourceExtensions.has(extname(entry.name)) ? [path] : [];
  });
}

const packageDirectories = readdirSync(packagesRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort();

for (const packageName of packageDirectories) {
  const packageRoot = join(packagesRoot, packageName);
  const manifest = parseJson<PackageManifest>(join(packageRoot, "package.json"));
  if (manifest.name !== `${INTERNAL_PREFIX}${packageName}`) {
    violations.push(`${packageRoot}: nom de package incohérent (${manifest.name ?? "absent"})`);
  }
  for (const script of REQUIRED_SCRIPTS) {
    if (!manifest.scripts?.[script]) violations.push(`${packageRoot}: script ${script} absent`);
  }

  const tsconfigPath = join(packageRoot, "tsconfig.json");
  try {
    const tsconfig = parseJson<{ extends?: string }>(tsconfigPath);
    if (tsconfig.extends !== "../../tsconfig.json") {
      violations.push(`${tsconfigPath}: doit étendre le tsconfig strict racine`);
    }
  } catch {
    violations.push(`${tsconfigPath}: configuration TypeScript absente ou invalide`);
  }

  for (const file of sourceFiles(join(packageRoot, "src"))) {
    const source = readFileSync(file, "utf8");
    for (const match of source.matchAll(importPattern)) {
      const imported = match[1];
      if (!imported) continue;
      if (imported.startsWith(INTERNAL_PREFIX)) {
        const dependency = imported.slice(INTERNAL_PREFIX.length).split("/")[0];
        if (dependency && dependency !== packageName && !allowedInternalDependencies[packageName]?.has(dependency)) {
          violations.push(`${relative(".", file)}: ${packageName} ne peut pas importer ${dependency}`);
        }
      }
      if (imported.startsWith(".")) {
        const destination = relative(resolve(packagesRoot), resolve(dirname(file), imported));
        const dependency = destination.split(/[\\/]/)[0];
        if (dependency && dependency !== ".." && dependency !== packageName && packageDirectories.includes(dependency)
          && !allowedInternalDependencies[packageName]?.has(dependency)) {
          violations.push(`${relative(".", file)}: import relatif interdit de ${packageName} vers ${dependency}`);
        }
      }
      if (frameworkIndependentPackages.has(packageName) && frameworkImports.some((name) => (
        imported === name || imported.startsWith(name.endsWith("/") ? name : `${name}/`)
      ))) {
        violations.push(`${relative(".", file)}: ${packageName} doit rester indépendant de ${imported}`);
      }
    }
  }
}

if (violations.length > 0) {
  throw new Error(`Frontières de modules invalides:\n- ${violations.join("\n- ")}`);
}

console.log(`Frontières et gates validées pour ${packageDirectories.length} packages.`);
