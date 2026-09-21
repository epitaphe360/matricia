import { z } from "zod";

const rowSchema = z.object({
  displayName: z.string().trim().min(2).max(200),
  contactEmail: z.string().trim().email(),
  organizationName: z.string().trim().max(200),
});

export type FranchiseProviderCsvRow = z.infer<typeof rowSchema>;

const MAX_ROWS = 50;

function splitLine(line: string) {
  const delimiter = line.includes(";") && !line.includes(",") ? ";" : ",";
  return line.split(delimiter).map((cell) => cell.trim().replace(/^"|"$/gu, "").replace(/""/gu, '"'));
}

export function parseFranchiseProviderCsv(text: string): { status: "ok"; rows: FranchiseProviderCsvRow[] } | { status: "error"; reason: "EMPTY" | "TOO_MANY" | "INVALID" } {
  const lines = text.split(/\r?\n/u).map((line) => line.trim()).filter(Boolean);
  if (!lines[0]) return { status: "error", reason: "EMPTY" };
  const header = splitLine(lines[0]).join(" ").toLowerCase();
  const body = /email|courriel|e-mail|اسم|بريد/u.test(header) ? lines.slice(1) : lines;
  if (!body.length) return { status: "error", reason: "EMPTY" };
  if (body.length > MAX_ROWS) return { status: "error", reason: "TOO_MANY" };
  const rows: FranchiseProviderCsvRow[] = [];
  for (const line of body) {
    const [displayName, contactEmail, organizationName = ""] = splitLine(line);
    const parsed = rowSchema.safeParse({ displayName, contactEmail, organizationName });
    if (!parsed.success) return { status: "error", reason: "INVALID" };
    rows.push(parsed.data);
  }
  return { status: "ok", rows };
}
