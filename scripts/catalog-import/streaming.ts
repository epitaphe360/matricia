import { createReadStream } from 'node:fs';
import { createInterface } from 'node:readline';

export async function* csvRecords(path: string): AsyncGenerator<{ lineNumber: number; value: Record<string, string> }> {
  const stream = createReadStream(path, { encoding: 'utf8' });
  let record: string[] = []; let field = ''; let quoted = false; let afterQuote = false; let lineNumber = 1; let recordLine = 1;
  let headers: string[] | undefined;
  for await (const chunk of stream) {
    for (let index = 0; index < chunk.length; index += 1) {
      const char = chunk[index];
      if (afterQuote) {
        if (char === '"') { field += '"'; quoted = true; afterQuote = false; continue; }
        afterQuote = false;
      }
      if (quoted) {
        if (char === '"') { quoted = false; afterQuote = true; }
        else { field += char; if (char === '\n') lineNumber += 1; }
      } else if (char === '"') {
        if (field.length) throw new Error(`CSV_UNEXPECTED_QUOTE:${path}:${lineNumber}`);
        quoted = true;
      } else if (char === ',') { record.push(field); field = ''; }
      else if (char === '\n') {
        record.push(field.replace(/\r$/, '')); field = '';
        if (!headers) headers = record.map((item) => item.replace(/^\uFEFF/, ''));
        else if (record.some((item) => item.length > 0)) {
          if (record.length !== headers.length) throw new Error(`CSV_COLUMN_COUNT:${path}:${recordLine}`);
          yield { lineNumber: recordLine, value: Object.fromEntries(headers.map((header, offset) => [header, record[offset]!])) };
        }
        record = []; lineNumber += 1; recordLine = lineNumber;
      } else field += char;
    }
  }
  if (quoted) throw new Error(`CSV_UNTERMINATED_QUOTE:${path}:${recordLine}`);
  if (field.length || record.length) {
    record.push(field.replace(/\r$/, ''));
    if (!headers) return;
    if (record.length !== headers.length) throw new Error(`CSV_COLUMN_COUNT:${path}:${recordLine}`);
    yield { lineNumber: recordLine, value: Object.fromEntries(headers.map((header, offset) => [header, record[offset]!])) };
  }
}

export async function* jsonLines(path: string): AsyncGenerator<{ lineNumber: number; value: Record<string, unknown> }> {
  const lines = createInterface({ input: createReadStream(path, { encoding: 'utf8' }), crlfDelay: Infinity });
  let lineNumber = 0;
  for await (const line of lines) {
    lineNumber += 1; if (!line.trim()) continue;
    let value: unknown;
    try { value = JSON.parse(line); } catch { throw new Error(`JSONL_INVALID:${path}:${lineNumber}`); }
    if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error(`JSONL_OBJECT_REQUIRED:${path}:${lineNumber}`);
    yield { lineNumber, value: value as Record<string, unknown> };
  }
}

export function chunks<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let offset = 0; offset < values.length; offset += size) result.push(values.slice(offset, offset + size));
  return result;
}
