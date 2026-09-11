import { createHash } from "node:crypto";
import { DocumentScanError } from "./errors";

const PDF = Buffer.from("%PDF-", "ascii");
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

function beginsWith(content: Uint8Array, signature: Uint8Array): boolean {
  return content.length >= signature.length && signature.every((byte, index) => content[index] === byte);
}

export function detectDocumentMimeType(content: Uint8Array): string {
  if (beginsWith(content, PDF)) return "application/pdf";
  if (beginsWith(content, PNG)) return "image/png";
  if (content.length >= 3 && content[0] === 0xff && content[1] === 0xd8 && content[2] === 0xff) return "image/jpeg";
  throw new DocumentScanError("DOCUMENT_MIME_UNSUPPORTED");
}

export function computeDocumentEvidence(content: Uint8Array, maximumBytes: number): Readonly<{
  sha256: string;
  mimeType: string;
  sizeBytes: number;
}> {
  if (!Number.isSafeInteger(maximumBytes) || maximumBytes < 1 || content.byteLength > maximumBytes) {
    throw new DocumentScanError("DOCUMENT_TOO_LARGE");
  }
  return Object.freeze({
    sha256: createHash("sha256").update(content).digest("hex"),
    mimeType: detectDocumentMimeType(content),
    sizeBytes: content.byteLength,
  });
}
