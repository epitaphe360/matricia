import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { promisify } from "node:util";
import { expect, test } from "@playwright/test";

const execFileAsync = promisify(execFile);
const root = resolve(import.meta.dirname, "..", "..");

type Scenario = {
  name: string;
  proofs: Array<{ file: string; markers: string[] }>;
};

const scenarios: Scenario[] = [
  { name: "01 client pays provider directly without Matricia holding principal", proofs: [{ file: "0112_v41_finance_workflow_commands.test.sql", markers: ["MATRICIA_NEVER_HOLDS_PRINCIPAL", "direct payment binds mission"] }] },
  { name: "02 provider commission is generated and reconciled after an eligible rule", proofs: [{ file: "0112_v41_finance_workflow_commands.test.sql", markers: ["PROVIDER_COMMISSION_RECEIPT", "atomically allocated"] }] },
  { name: "03 client subscription uses configured and versioned Morocco taxation", proofs: [{ file: "0052_p15_subscription_plans_cycles.test.sql", markers: ["immutable plan version"] }, { file: "0060_p14_morocco_tax_engine.test.sql", markers: ["database-resolved HT to TVA to TTC"] }] },
  { name: "04 credit purchase supports an immutable partial refund", proofs: [{ file: "0112_v41_finance_workflow_commands.test.sql", markers: ["MATRICIA_OWN_REFUND", "refund event reverses own revenue"] }] },
  { name: "05 consumed Box combines provider and AI costs into actual margin", proofs: [{ file: "0115_v41_finops_reconciliation_commands.test.sql", markers: ["actual margin", "AI invoice"] }] },
  { name: "06 supplier invoice traverses approval payment and reconciliation", proofs: [{ file: "0112_v41_finance_workflow_commands.test.sql", markers: ["three-way matching", "AP reconciliation"] }] },
  { name: "07 bank-account change enforces four-eyes and cooling period", proofs: [{ file: "0108_v41_finance_boundaries_procurement_rib.test.sql", markers: ["four-eyes", "cooling"] }] },
  { name: "08 contract signature reaches SIGNED through provider evidence", proofs: [{ file: "0109_v41_signature_provider_evidence.test.sql", markers: ["SIGNED", "evidence"] }] },
  { name: "09 signed contract changes create an amendment without mutation", proofs: [{ file: "0109_v41_signature_provider_evidence.test.sql", markers: ["amendment", "immutable"] }] },
  { name: "10 replayed signature webhook causes one transition", proofs: [{ file: "0109_v41_signature_provider_evidence.test.sql", markers: ["replay", "transition"] }] },
  { name: "11 replayed own-payment webhook causes one ledger entry", proofs: [{ file: "0112_v41_finance_workflow_commands.test.sql", markers: ["PAYMENT_EVENT_REPLAY_MISMATCH", "anti-replay"] }] },
  { name: "12 data-subject request export and rectification are audited", proofs: [{ file: "0110_v41_privacy_governance.test.sql", markers: ["registers a scoped DSR", "audit"] }] },
  { name: "13 legal hold blocks purge", proofs: [{ file: "0110_v41_privacy_governance.test.sql", markers: ["legal hold blocks anonymization"] }, { file: "0113_v41_resilience_security_registry.test.sql", markers: ["LEGAL_HOLD_BLOCKS_PURGE"] }] },
  { name: "14 non-compliant international transfer blocks production readiness", proofs: [{ file: "0110_v41_privacy_governance.test.sql", markers: ["international transfer", "production gate"] }] },
  { name: "15 external provider outage retries then dead-letters without corruption", proofs: [{ file: "0113_v41_resilience_security_registry.test.sql", markers: ["RETRYABLE_FAILURE", "DEAD_LETTER"] }] },
  { name: "16 backup restore requires retained integrity evidence", proofs: [{ file: "0113_v41_resilience_security_registry.test.sql", markers: ["restore", "evidence"] }] },
  { name: "17 franchise user cannot alter protected financial rules", proofs: [{ file: "0114_v41_legal_governance_marketing.test.sql", markers: ["franchise", "DENY"] }] },
  { name: "18 marketing publication is blocked without required consent", proofs: [{ file: "0114_v41_legal_governance_marketing.test.sql", markers: ["consent", "blocked"] }] },
  { name: "19 historical invoice and ledger entries remain immutable", proofs: [{ file: "0003_immutable_ledgers.test.sql", markers: ["immutable"] }, { file: "0112_v41_finance_workflow_commands.test.sql", markers: ["immutable evidence"] }] },
  { name: "20 tenant A cannot read tenant B data in new modules", proofs: [{ file: "0110_v41_privacy_governance.test.sql", markers: ["cannot read another tenant"] }, { file: "0113_v41_resilience_security_registry.test.sql", markers: ["DENY cross-tenant"] }] },
  { name: "21 admin submits and independently validates external readiness evidence", proofs: [{ file: "0117_v41_admin_external_validations.test.sql", markers: ["four-eyes", "optimistic concurrency", "authenticated-only"] }] },
];

const proofFiles = [...new Set(scenarios.flatMap(({ proofs }) => proofs.map(({ file }) => file)))];
const testPattern = `^(${proofFiles.map((file) => file.slice(0, 4)).join("|")})_`;
let databaseProof = "";

test.describe.configure({ mode: "serial", timeout: 180_000 });

test.beforeAll(async () => {
  const { stdout } = await execFileAsync(process.execPath, [resolve(root, "scripts", "run-db-tests.mjs")], {
    cwd: root,
    env: { ...process.env, DB_TEST_PATTERN: testPattern },
    maxBuffer: 4 * 1024 * 1024,
    timeout: 170_000,
  });
  databaseProof = stdout;
});

for (const scenario of scenarios) {
  test(scenario.name, async () => {
    for (const proof of scenario.proofs) {
      expect(databaseProof).toContain(`PASS ${proof.file}`);
      const source = await readFile(resolve(root, "supabase", "tests", proof.file), "utf8");
      expect(
        proof.markers.some((marker) => source.toLowerCase().includes(marker.toLowerCase())),
        `${proof.file} must retain an explicit scenario marker`,
      ).toBe(true);
    }
  });
}
