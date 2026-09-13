import { createHash, createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import { isIP } from "node:net";

import { getSupabaseAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

const headers = { "cache-control": "no-store" } as const;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Claim={proof_id:unknown;lease_token:unknown;worker_id:unknown;row_version:unknown;attempt_count:unknown;storage_bucket:unknown;storage_path:unknown;expected_sha256:unknown;media_type:unknown};

function authorized(request:Request){const expected=process.env.CRON_SECRET??"",supplied=request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1]??"",a=Buffer.from(expected),b=Buffer.from(supplied);return a.length>=32&&a.length===b.length&&timingSafeEqual(a,b)}
function requestedLimit(request:Request){const raw=new URL(request.url).searchParams.get("limit")??"2";if(!/^\d{1,3}$/.test(raw))return null;const value=Number(raw);return Number.isSafeInteger(value)&&value>=1&&value<=100?Math.min(value,2):null}
function validClaim(value:Claim,workerId:string){return typeof value.proof_id==="string"&&UUID.test(value.proof_id)&&typeof value.lease_token==="string"&&UUID.test(value.lease_token)&&value.worker_id===workerId&&Number.isSafeInteger(value.row_version)&&(value.row_version as number)>0&&Number.isSafeInteger(value.attempt_count)&&(value.attempt_count as number)>=0&&(value.attempt_count as number)<5&&value.storage_bucket==="delivery-proofs"&&typeof value.storage_path==="string"&&value.storage_path.length<=500&&/^[0-9a-f]{64}$/.test(String(value.expected_sha256))}
type ScanVerdict={result:"CLEAN"|"INFECTED"|"ERROR";engineCode:string;engineVersion:string;retryable?:boolean;retryCode?:"SCANNER_UNAVAILABLE"|"SCANNER_INVALID_RESPONSE"};
function sandboxInspect(bytes:Buffer,mediaType:unknown):ScanVerdict{const eicar=bytes.includes(Buffer.from("EICAR-STANDARD-ANTIVIRUS-TEST-FILE"));if(eicar)return{result:"INFECTED",engineCode:"MATRICIA_SANDBOX",engineVersion:"1.0.0"};const pdf=bytes.subarray(0,5).toString()==="%PDF-",jpeg=bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff,png=bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));return{result:(mediaType==="application/pdf"&&pdf)||(mediaType==="image/jpeg"&&jpeg)||(mediaType==="image/png"&&png)?"CLEAN":"ERROR",engineCode:"MATRICIA_SANDBOX",engineVersion:"1.0.0"}}
function safeEqualHex(actual:string,expected:string){if(!/^[0-9a-f]{64}$/i.test(actual)||!/^[0-9a-f]{64}$/i.test(expected))return false;return timingSafeEqual(Buffer.from(actual,"hex"),Buffer.from(expected,"hex"))}
function privateAddress(raw:string){const address=raw.toLowerCase().split("%")[0];if(address.startsWith("::ffff:")){const mapped=address.slice(7);if(isIP(mapped)===4)return privateAddress(mapped);const hex=mapped.match(/^([0-9a-f]{1,4}):([0-9a-f]{1,4})$/);if(!hex)return true;const high=Number.parseInt(hex[1]!,16),low=Number.parseInt(hex[2]!,16);return privateAddress(`${high>>>8}.${high&255}.${low>>>8}.${low&255}`);}if(isIP(address)===4){const [a,b]=address.split(".").map(Number);return a===0||a===10||a===127||a>=224||(a===100&&b>=64&&b<=127)||(a===169&&b===254)||(a===172&&b>=16&&b<=31)||(a===192&&b===168)||(a===198&&(b===18||b===19));}return isIP(address)===6&&(address==="::"||address==="::1"||address.startsWith("fc")||address.startsWith("fd")||/^fe[89ab]/.test(address)||address.startsWith("ff"));}
async function scan(bytes:Buffer,sha256:string,mediaType:unknown):Promise<ScanVerdict>{
  if(process.env.DELIVERY_PROOF_SCANNER_MODE==="SANDBOX"&&process.env.NODE_ENV!=="production")return sandboxInspect(bytes,mediaType);
  const endpoint=process.env.MALWARE_SCANNER_URL??"",token=process.env.MALWARE_SCANNER_TOKEN??"";
  const allowed=(process.env.MALWARE_SCANNER_ALLOWED_HOSTS??"").split(",").map(value=>value.trim().toLowerCase()).filter(Boolean);
  let url:URL;try{url=new URL(endpoint)}catch{return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true,retryCode:"SCANNER_UNAVAILABLE"}}
  const host=url.hostname.toLowerCase().replace(/^\[|\]$/g,""),literalIp=isIP(host)!==0;
  if(url.protocol!=="https:"||url.username||url.password||(url.port&&url.port!=="443")||!literalIp||privateAddress(host)||!allowed.includes(host)||token.length<32)return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true,retryCode:"SCANNER_UNAVAILABLE"};
  try{
    const response=await fetch(url,{method:"POST",headers:{authorization:`Bearer ${token}`,"content-type":"application/json"},body:JSON.stringify({sha256,mediaType,contentBase64:bytes.toString("base64")}),signal:AbortSignal.timeout(20_000),redirect:"error"});
    const declared=Number(response.headers.get("content-length")??"0");if(declared>32768)return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true};
    const body=await response.text();if(Buffer.byteLength(body)>32768)return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true};const signature=response.headers.get("x-scan-signature")??"",expected=createHmac("sha256",token).update(body).digest("hex");
    if(!response.ok||!safeEqualHex(signature,expected))return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true};
    const parsed=JSON.parse(body) as Record<string,unknown>;
    if((parsed.result!=="CLEAN"&&parsed.result!=="INFECTED")||parsed.sha256!==sha256||typeof parsed.engineCode!=="string"||!/^[A-Z][A-Z0-9_.-]{2,79}$/.test(parsed.engineCode)||typeof parsed.engineVersion!=="string"||parsed.engineVersion.trim().length<1||parsed.engineVersion.length>80)return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true};
    return{result:parsed.result,engineCode:parsed.engineCode,engineVersion:parsed.engineVersion};
  }catch{return{result:"ERROR",engineCode:"MATRICIA_FAIL_CLOSED",engineVersion:"1.0.0",retryable:true,retryCode:"SCANNER_UNAVAILABLE"}}
}

export async function POST(request:Request){
  if(!authorized(request))return Response.json({code:"UNAUTHORIZED"},{status:401,headers});
  const limit=requestedLimit(request);if(!limit)return Response.json({code:"INVALID_LIMIT"},{status:400,headers});
  const client=getSupabaseAdminClient(),workerId=randomUUID(),correlationId=randomUUID();
  try{
    const claimed=await client.rpc("claim_delivery_proof_scan_jobs",{p_worker_id:workerId,p_limit:limit,p_lease_seconds:300});
    if(claimed.error||!Array.isArray(claimed.data))return Response.json({code:"DELIVERY_PROOF_SCAN_CLAIM_FAILED"},{status:503,headers});
    let completed=0,retried=0;
    for(const claim of claimed.data as Claim[]){
      if(!validClaim(claim,workerId))return Response.json({code:"DELIVERY_PROOF_SCAN_INVALID_CLAIM"},{status:503,headers});
      const downloaded=await client.storage.from("delivery-proofs").download(claim.storage_path as string);
      if(downloaded.error||!downloaded.data){const failed=await client.rpc("fail_delivery_proof_scan_job",{p_proof_id:claim.proof_id,p_lease_token:claim.lease_token,p_worker_id:workerId,p_expected_row_version:claim.row_version,p_failure_code:"STORAGE_DOWNLOAD_FAILED",p_computed_sha256:claim.expected_sha256,p_correlation_id:correlationId});if(failed.error||!["DELIVERY_PROOF_SCAN_RETRY_SCHEDULED","DELIVERY_PROOF_SCAN_DEAD_LETTERED"].includes(String(failed.data?.outcome)))return Response.json({code:"DELIVERY_PROOF_SCAN_RETRY_FAILED"},{status:503,headers});retried++;continue;}
      const array=await downloaded.data.arrayBuffer();if(array.byteLength>10*1024*1024)return Response.json({code:"DELIVERY_PROOF_SCAN_OBJECT_TOO_LARGE"},{status:503,headers});const bytes=Buffer.from(array),computed=createHash("sha256").update(bytes).digest("hex"),verdict=computed===claim.expected_sha256?await scan(bytes,computed,claim.media_type):{result:"ERROR" as const,engineCode:"MATRICIA_HASH_GUARD",engineVersion:"1.0.0"};
      if(verdict.retryable){const failed=await client.rpc("fail_delivery_proof_scan_job",{p_proof_id:claim.proof_id,p_lease_token:claim.lease_token,p_worker_id:workerId,p_expected_row_version:claim.row_version,p_failure_code:verdict.retryCode??"SCANNER_INVALID_RESPONSE",p_computed_sha256:computed,p_correlation_id:correlationId});if(failed.error||!["DELIVERY_PROOF_SCAN_RETRY_SCHEDULED","DELIVERY_PROOF_SCAN_DEAD_LETTERED"].includes(String(failed.data?.outcome)))return Response.json({code:"DELIVERY_PROOF_SCAN_RETRY_FAILED"},{status:503,headers});retried++;continue;}
      const completedJob=await client.rpc("complete_delivery_proof_scan_job",{p_proof_id:claim.proof_id,p_lease_token:claim.lease_token,p_worker_id:workerId,p_expected_row_version:claim.row_version,p_result:verdict.result,p_engine_code:verdict.engineCode,p_engine_version:verdict.engineVersion,p_computed_sha256:computed,p_idempotency_key:`delivery-proof-scan:${claim.proof_id}:${claim.expected_sha256}`,p_correlation_id:correlationId});
      if(completedJob.error||completedJob.data?.outcome!=="DELIVERY_PROOF_SCAN_RECORDED")return Response.json({code:"DELIVERY_PROOF_SCAN_COMPLETION_FAILED"},{status:503,headers});completed++;
    }
    const cleanup=await client.rpc("cleanup_delivery_proof_storage_orphans",{p_limit:limit,p_correlation_id:correlationId});
    if(cleanup.error||cleanup.data?.outcome!=="DELIVERY_PROOF_ORPHANS_CLEANED"||!Number.isSafeInteger(cleanup.data?.count))return Response.json({code:"DELIVERY_PROOF_ORPHAN_CLEANUP_FAILED"},{status:503,headers});
    return Response.json({outcome:"DELIVERY_PROOF_SCANS_PROCESSED",orphansCleaned:cleanup.data.count,claimed:claimed.data.length,completed,retried},{headers:{...headers,"x-correlation-id":correlationId}});
  }catch{return Response.json({code:"DELIVERY_PROOF_SCAN_WORKER_FAILED"},{status:503,headers})}
}
export const GET=POST;
