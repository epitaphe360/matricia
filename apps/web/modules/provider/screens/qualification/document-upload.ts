import { createHash } from "node:crypto";

export const PROVIDER_DOCUMENT_MAX_BYTES = 10 * 1024 * 1024;
export const PROVIDER_DOCUMENT_MIME_TYPES = ["application/pdf", "image/jpeg", "image/png"] as const;

type AcceptedMime = (typeof PROVIDER_DOCUMENT_MIME_TYPES)[number];
type ValidatedFile = { bytes: Uint8Array; mimeType: AcceptedMime; sizeBytes: number; sha256: string };
export type ProviderDocumentFileResult = { status: "success"; value: ValidatedFile } | { status: "error" };

function hasExpectedSignature(bytes: Uint8Array, mimeType: AcceptedMime) {
  if (mimeType === "application/pdf") return bytes.length >= 5 && new TextDecoder().decode(bytes.subarray(0, 5)) === "%PDF-";
  if (mimeType === "image/jpeg") return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  return bytes.length >= 8 && [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((value, index) => bytes[index] === value);
}

export async function validateProviderDocumentFile(entry: FormDataEntryValue | null): Promise<ProviderDocumentFileResult> {
  if (!(entry instanceof File) || entry.size < 1 || entry.size > PROVIDER_DOCUMENT_MAX_BYTES) return { status: "error" };
  if (!PROVIDER_DOCUMENT_MIME_TYPES.includes(entry.type as AcceptedMime)) return { status: "error" };
  try {
    const bytes = new Uint8Array(await entry.arrayBuffer());
    const mimeType = entry.type as AcceptedMime;
    if (!hasExpectedSignature(bytes, mimeType)) return { status: "error" };
    return { status: "success", value: { bytes, mimeType, sizeBytes: bytes.byteLength, sha256: createHash("sha256").update(bytes).digest("hex") } };
  } catch { return { status: "error" }; }
}
