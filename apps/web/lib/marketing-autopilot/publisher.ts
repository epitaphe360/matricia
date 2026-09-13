import { z } from "zod";

const contentSchema=z.object({language:z.enum(["FR","AR"]),hook:z.string().max(300),body:z.string().max(6000),cta:z.string().max(300),hashtags:z.array(z.string()).max(30),landing_url:z.string().url(),media_url:z.string().url().nullable().optional()});
export const publicationJobSchema=z.object({outcome:z.literal("JOB_CLAIMED"),job_id:z.string().uuid(),attempt:z.number().int().positive(),provider:z.enum(["LINKEDIN","META"]),channel:z.enum(["LINKEDIN","FACEBOOK","INSTAGRAM","REEL"]),credential_reference:z.string().regex(/^env:\/\/[A-Z][A-Z0-9_]{7,99}$/),content:contentSchema});
export type PublicationJob=z.infer<typeof publicationJobSchema>;
export type PublicationResult={outcome:"PUBLISHED";providerPublicationId:string}|{outcome:"SANDBOXED"}|{outcome:"RETRYABLE_FAILURE"|"PERMANENT_FAILURE";errorCode:string};
type Runtime={mode:"sandbox"|"live";liveEnabled:boolean;environment:Record<string,string|undefined>;fetch:typeof fetch};
const linkedInCredential=z.object({accessToken:z.string().min(20),authorUrn:z.string().regex(/^urn:li:(?:person|organization):[A-Za-z0-9_-]+$/),apiVersion:z.string().regex(/^20\d{4}$/)});
const metaCredential=z.object({accessToken:z.string().min(20),targetId:z.string().regex(/^\d{3,40}$/),graphVersion:z.string().regex(/^v\d{2,3}\.\d$/)});

export async function publishScheduledSocial(job:PublicationJob,runtime:Runtime):Promise<PublicationResult>{
  if(runtime.mode==="sandbox")return{outcome:"SANDBOXED"};
  if(!runtime.liveEnabled)return{outcome:"PERMANENT_FAILURE",errorCode:"LIVE_PUBLISHING_DISABLED"};
  const variable=job.credential_reference.slice(6),raw=runtime.environment[variable];
  if(!raw)return{outcome:"PERMANENT_FAILURE",errorCode:"CREDENTIAL_REFERENCE_UNRESOLVED"};
  try{return job.provider==="LINKEDIN"?await publishLinkedIn(job,linkedInCredential.parse(JSON.parse(raw)),runtime.fetch):await publishMeta(job,metaCredential.parse(JSON.parse(raw)),runtime.fetch)}catch(error){return{outcome:"PERMANENT_FAILURE",errorCode:error instanceof z.ZodError?"INVALID_CREDENTIAL_CONFIGURATION":"PROVIDER_CONFIGURATION_ERROR"}}
}

function message(job:PublicationJob){return [job.content.hook,job.content.body,job.content.cta,job.content.landing_url,job.content.hashtags.join(" ")].filter(Boolean).join("\n\n").slice(0,6000)}
async function publishLinkedIn(job:PublicationJob,credential:z.infer<typeof linkedInCredential>,request:typeof fetch):Promise<PublicationResult>{
  if(job.channel!=="LINKEDIN")return{outcome:"PERMANENT_FAILURE",errorCode:"PROVIDER_CHANNEL_MISMATCH"};
  const response=await request("https://api.linkedin.com/rest/posts",{method:"POST",headers:{authorization:`Bearer ${credential.accessToken}`,"content-type":"application/json","linkedin-version":credential.apiVersion,"x-restli-protocol-version":"2.0.0"},body:JSON.stringify({author:credential.authorUrn,commentary:message(job),visibility:"PUBLIC",distribution:{feedDistribution:"MAIN_FEED",targetEntities:[],thirdPartyDistributionChannels:[]},lifecycleState:"PUBLISHED",isReshareDisabledByAuthor:false})});
  if(response.status===201){const id=response.headers.get("x-restli-id");return id?{outcome:"PUBLISHED",providerPublicationId:id}:{outcome:"RETRYABLE_FAILURE",errorCode:"PROVIDER_ID_MISSING"}}
  return providerFailure(response.status);
}
async function publishMeta(job:PublicationJob,credential:z.infer<typeof metaCredential>,request:typeof fetch):Promise<PublicationResult>{
  const base=`https://graph.facebook.com/${credential.graphVersion}/${credential.targetId}`,headers={authorization:`Bearer ${credential.accessToken}`,"content-type":"application/json"};
  if(job.channel==="FACEBOOK"){const response=await request(`${base}/feed`,{method:"POST",headers,body:JSON.stringify({message:message(job),link:job.content.landing_url})});return jsonId(response)}
  if(job.channel!=="INSTAGRAM"&&job.channel!=="REEL")return{outcome:"PERMANENT_FAILURE",errorCode:"PROVIDER_CHANNEL_MISMATCH"};
  if(!job.content.media_url)return{outcome:"PERMANENT_FAILURE",errorCode:"META_MEDIA_URL_REQUIRED"};
  const create=await request(`${base}/media`,{method:"POST",headers,body:JSON.stringify(job.channel==="REEL"?{media_type:"REELS",video_url:job.content.media_url,caption:message(job)}:{image_url:job.content.media_url,caption:message(job)})});
  if(!create.ok)return providerFailure(create.status);const created=z.object({id:z.string().min(1)}).safeParse(await create.json());if(!created.success)return{outcome:"RETRYABLE_FAILURE",errorCode:"PROVIDER_ID_MISSING"};
  return jsonId(await request(`${base}/media_publish`,{method:"POST",headers,body:JSON.stringify({creation_id:created.data.id})}));
}
async function jsonId(response:Response):Promise<PublicationResult>{if(!response.ok)return providerFailure(response.status);const parsed=z.object({id:z.string().min(1)}).safeParse(await response.json());return parsed.success?{outcome:"PUBLISHED",providerPublicationId:parsed.data.id}:{outcome:"RETRYABLE_FAILURE",errorCode:"PROVIDER_ID_MISSING"}}
function providerFailure(status:number):PublicationResult{return status===408||status===425||status===429||status>=500?{outcome:"RETRYABLE_FAILURE",errorCode:`PROVIDER_HTTP_${status}`}:{outcome:"PERMANENT_FAILURE",errorCode:`PROVIDER_HTTP_${status}`}}
