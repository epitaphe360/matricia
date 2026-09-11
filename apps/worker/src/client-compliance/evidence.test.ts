import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import { computeDocumentEvidence, detectDocumentMimeType } from "./evidence";

describe("server document evidence", () => {
  it.each([
    [new Uint8Array(Buffer.from("%PDF-1.7", "ascii")), "application/pdf"],
    [new Uint8Array([0xff, 0xd8, 0xff, 0xe0]), "image/jpeg"],
    [new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), "image/png"],
  ])("detects supported magic bytes", (bytes, mime) => {
    expect(detectDocumentMimeType(bytes)).toBe(mime);
  });

  it("computes an exact SHA-256 and size", () => {
    const bytes = new Uint8Array(Buffer.from("%PDF-exact", "ascii"));
    expect(computeDocumentEvidence(bytes, 100)).toEqual({
      sha256: createHash("sha256").update(bytes).digest("hex"),
      mimeType: "application/pdf",
      sizeBytes: bytes.byteLength,
    });
  });

  it("rejects unknown signatures and oversized payloads", () => {
    expect(() => detectDocumentMimeType(new Uint8Array([1, 2, 3]))).toThrow("DOCUMENT_MIME_UNSUPPORTED");
    expect(() => computeDocumentEvidence(new Uint8Array(Buffer.from("%PDF-large")), 3)).toThrow("DOCUMENT_TOO_LARGE");
  });
});
