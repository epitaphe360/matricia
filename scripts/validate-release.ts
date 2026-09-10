import { spawnSync } from "node:child_process";

const checks = ["validate-catalog.ts", "validate-spec.ts", "validate-traceability.ts", "validate-no-placeholders.ts"];
for (const check of checks) {
  const result = spawnSync(process.execPath, ["--experimental-strip-types", `scripts/${check}`], { stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
console.log("Gates structurels Matricia validés.");
