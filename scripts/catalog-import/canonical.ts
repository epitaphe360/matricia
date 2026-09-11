import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';

export function canonicalJson(value: unknown): string {
  if (value === null || typeof value === 'boolean' || typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) throw new Error('CANONICAL_NUMBER_MUST_BE_SAFE_INTEGER');
    return String(value);
  }
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (typeof value === 'object') return `{${Object.entries(value as Record<string, unknown>).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([key, item]) => `${JSON.stringify(key)}:${canonicalJson(item)}`).join(',')}}`;
  throw new Error('CANONICAL_JSON_UNSUPPORTED_VALUE');
}

export function sha256Text(value: string): string { return createHash('sha256').update(value.normalize('NFC'), 'utf8').digest('hex'); }

export async function sha256File(path: string): Promise<{ sha256: string; byteSize: number }> {
  const hash = createHash('sha256'); let byteSize = 0;
  for await (const chunk of createReadStream(path)) { const bytes = chunk as Buffer; byteSize += bytes.length; hash.update(bytes); }
  return { sha256: hash.digest('hex'), byteSize };
}
