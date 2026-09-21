import { readFile, readdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import postgres from "postgres";

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/u).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/u);
    return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/u, "$2")]] : [];
  }));
}

function escapeCell(value) { return String(value).replaceAll("|", "\\|").replace(/\s+/gu, " ").trim(); }

const env = parseEnv(await readFile(".env.local", "utf8"));
const url = new URL(env.DIRECT_URL ?? "");
if (url.protocol !== "postgresql:") throw new Error("DIRECT_URL_REQUIRED");
if (url.hostname.startsWith("db.") && url.hostname.endsWith(".supabase.co")) {
  const projectRef = url.hostname.split(".")[1];
  const metadata = JSON.parse(await readFile(resolve("supabase", "project-metadata.json"), "utf8"));
  if (!metadata.region || metadata.project_ref !== projectRef) throw new Error("SUPABASE_REGION_METADATA_REQUIRED");
  url.hostname = `aws-0-${metadata.region}.pooler.supabase.com`;
  url.port = "5432";
  url.username = `postgres.${projectRef}`;
  url.searchParams.set("sslmode", "require");
}

const testNames = (await readdir(resolve("supabase", "tests"))).filter((name) => name.endsWith(".test.sql")).sort();
const tests = await Promise.all(testNames.map(async (name) => ({ name, source: await readFile(resolve("supabase", "tests", name), "utf8") })));
const sql = postgres(url.toString(), { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 1 });
let rows;
try {
  rows = await sql.begin(async (transaction) => {
    await transaction.unsafe("set transaction read only");
    return transaction`
      select p.oid::regprocedure::text as signature,
             p.proname as name,
             pg_get_functiondef(p.oid) as definition
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prosecdef
        and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      order by p.proname, p.oid::regprocedure::text
    `;
  });
} finally {
  await sql.end({ timeout: 1 });
}

const mapped = rows.map((row) => {
  const pattern = new RegExp(`\\b${row.name.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&")}\\b`, "u");
  const references = tests.filter((test) => pattern.test(test.source));
  const evidence = references.map((test) => test.name);
  const joined = references.map((test) => test.source).join("\n");
  const positive = references.length > 0 && /lives_ok|outcome|succeeds|allowed|autorisé|autorisee|autorise|can execute|returns?/iu.test(joined);
  const negative = references.length > 0 && /throws_ok|denied|forbidden|cannot|interdit|refus|cross[-_ ]tenant|other tenant/iu.test(joined);
  const helperMatches = [...new Set([...row.definition.matchAll(/private\.([a-z][a-z0-9_]*)\s*\(/gu)].map((match) => match[1]))].sort();
  return { signature: row.signature, evidence, positive, negative, helpers: helperMatches };
});

const counts = {
  total: mapped.length,
  referenced: mapped.filter((row) => row.evidence.length).length,
  positiveAndNegative: mapped.filter((row) => row.positive && row.negative).length,
  missingPositive: mapped.filter((row) => !row.positive).length,
  missingNegative: mapped.filter((row) => !row.negative).length,
};
const document = `# Matricia — couverture RPC de sécurité\n\n` +
  `Générée par \`node scripts/audit-rpc-security.mjs\` depuis les métadonnées Supabase development dans une transaction \`READ ONLY\` et les tests SQL locaux. La détection ALLOW/DENY est une heuristique textuelle : elle identifie la dette, mais ne remplace pas la revue humaine du scénario.\n\n` +
  `## Synthèse\n\n` +
  `- RPC publiques \`SECURITY DEFINER\` exécutables par \`authenticated\` : **${counts.total}**.\n` +
  `- Référencées dans au moins un test SQL : **${counts.referenced}**.\n` +
  `- Indices positifs et négatifs dans les tests associés : **${counts.positiveAndNegative}**.\n` +
  `- Sans indice positif : **${counts.missingPositive}**; sans indice négatif : **${counts.missingNegative}**.\n\n` +
  `## Matrice\n\n| Signature | Helpers d'autorisation détectés | Tests | ALLOW indicatif | DENY indicatif |\n|---|---|---|---:|---:|\n` +
  mapped.map((row) => `| \`${escapeCell(row.signature)}\` | ${row.helpers.length ? row.helpers.map((name) => `\`${name}\``).join(", ") : "revue requise"} | ${row.evidence.length ? row.evidence.join(", ") : "aucun"} | ${row.positive ? "OUI" : "NON"} | ${row.negative ? "OUI" : "NON"} |`).join("\n") +
  `\n\n## Gate\n\nUne RPC sensible ne passe pas sur la seule détection ci-dessus. Le test doit authentifier le rôle autorisé, constater l'effet ou la projection attendue, puis répéter avec rôle insuffisant et autre organisation.\n`;
await writeFile(resolve("docs", "RPC_SECURITY_TEST_MATRIX.md"), document, "utf8");
console.log(JSON.stringify(counts));
