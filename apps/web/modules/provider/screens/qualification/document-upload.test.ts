import { createHash } from "node:crypto";
import { describe,expect,it } from "vitest";
import { PROVIDER_DOCUMENT_MAX_BYTES,validateProviderDocumentFile } from "./document-upload";

describe("provider qualification document validation",()=>{
  const pdf=Uint8Array.from([0x25,0x50,0x44,0x46,0x2d,0x31]);
  it("accepts a real PDF signature and computes its digest",async()=>{const result=await validateProviderDocumentFile(new File([pdf],"preuve.pdf",{type:"application/pdf"}));expect(result.status).toBe("success");if(result.status==="success")expect(result.value.sha256).toBe(createHash("sha256").update(pdf).digest("hex"))});
  it("rejects a MIME label that does not match the bytes",async()=>{await expect(validateProviderDocumentFile(new File(["plain text"],"preuve.pdf",{type:"application/pdf"}))).resolves.toEqual({status:"error"})});
  it("rejects unsupported or oversized files",async()=>{await expect(validateProviderDocumentFile(new File(["x"],"preuve.txt",{type:"text/plain"}))).resolves.toEqual({status:"error"});await expect(validateProviderDocumentFile(new File([new Uint8Array(PROVIDER_DOCUMENT_MAX_BYTES+1)],"preuve.pdf",{type:"application/pdf"}))).resolves.toEqual({status:"error"})});
  it("fails closed when the browser cannot read the file",async()=>{const file=new File([pdf],"preuve.pdf",{type:"application/pdf"});Object.defineProperty(file,"arrayBuffer",{value:async()=>{throw new Error("unreadable")}});await expect(validateProviderDocumentFile(file)).resolves.toEqual({status:"error"})});
});
