import { generateServiceContent, generatedServiceContentSchema, serviceContentInput, type GeneratedServiceContent } from "./content-engine";
import type { z } from "zod";
import { isIP } from "node:net";

export type ServiceContentRequest = z.input<typeof serviceContentInput>;
export type MarketingContentProvider = {
  name: string;
  generate(request: ServiceContentRequest): Promise<GeneratedServiceContent[]>;
};
export type ProviderRun = { provider: string; contents: GeneratedServiceContent[]; failoverUsed: boolean };

export const deterministicSandboxProvider: MarketingContentProvider = {
  name: "DETERMINISTIC_SANDBOX",
  async generate(request) { return generateServiceContent(request); },
};

function publicIp(host:string){if(isIP(host)===4){const [a,b,c]=host.split(".").map(Number);return !(a===0||a===10||a===127||a>=224||(a===100&&b>=64&&b<=127)||(a===169&&b===254)||(a===172&&b>=16&&b<=31)||(a===192&&(b===0||b===168||b===2))||(a===198&&(b===18||b===19||b===51&&c===100))||(a===203&&b===0&&c===113))}if(isIP(host)!==6)return false;const first=Number.parseInt(host.split(":",1)[0]||"0",16);return first>=0x2000&&first<=0x3fff&&!host.startsWith("2001:db8:")}
async function boundedJson(response:Response){const declared=Number(response.headers.get("content-length")??"0");if(declared>262144)throw new Error("MARKETING_PROVIDER_RESPONSE_TOO_LARGE");const reader=response.body?.getReader();if(!reader)return null;const chunks:Uint8Array[]=[];let size=0;for(;;){const{done,value}=await reader.read();if(done)break;if(value){size+=value.byteLength;if(size>262144){await reader.cancel();throw new Error("MARKETING_PROVIDER_RESPONSE_TOO_LARGE")}chunks.push(value)}}const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength}return JSON.parse(new TextDecoder().decode(bytes))as unknown}
export function configuredExternalProvider(config:{endpoint:string;endpointAllowlist:string[];apiKey:string}):MarketingContentProvider{
  const endpoint=new URL(config.endpoint),host=endpoint.hostname.toLowerCase().replace(/^\[|\]$/g,"");if(endpoint.protocol!=="https:"||endpoint.username||endpoint.password||(endpoint.port&&endpoint.port!=="443")||!config.endpointAllowlist.includes(endpoint.href)||!publicIp(host)||config.apiKey.length<32)throw new Error("MARKETING_PROVIDER_CONFIG_INVALID");
  return{name:"CONFIGURED_EXTERNAL",async generate(request){const response=await fetch(endpoint,{method:"POST",headers:{authorization:`Bearer ${config.apiKey}`,"content-type":"application/json","user-agent":"matricia-marketing-worker/1",...(request.providerIdempotencyKey?{"idempotency-key":request.providerIdempotencyKey}:{})},body:JSON.stringify(request),signal:AbortSignal.timeout(20_000),redirect:"error"});if(!response.ok)throw new Error("MARKETING_PROVIDER_FAILED");const raw=await boundedJson(response);return generatedServiceContentSchema.array().length(3).parse(raw)}};
}

export function configuredProviders(env:NodeJS.ProcessEnv=process.env):readonly MarketingContentProvider[]{const endpoint=env.MARKETING_CONTENT_PROVIDER_URL,apiKey=env.MARKETING_CONTENT_PROVIDER_API_KEY,endpointAllowlist=(env.MARKETING_CONTENT_PROVIDER_ENDPOINT_ALLOWLIST??"").split(",").map(x=>x.trim()).filter(Boolean);const providers:MarketingContentProvider[]=[];if(endpoint&&apiKey&&endpointAllowlist.length)providers.push(configuredExternalProvider({endpoint,endpointAllowlist,apiKey}));if(env.NODE_ENV!=="production")providers.push(deterministicSandboxProvider);return providers}

function validBatch(contents: GeneratedServiceContent[]) {
  return contents.length === 3 && new Set(contents.map((item) => item.channel)).size === 3
    && contents.every((item) => item.contentHash.length === 64 && item.landingUrl.startsWith("https://"));
}

export async function generateWithFailover(request: ServiceContentRequest, providers: readonly MarketingContentProvider[]): Promise<ProviderRun> {
  if (!providers.length) throw new Error("MARKETING_PROVIDER_UNAVAILABLE");
  for (let index = 0; index < providers.length; index++) {
    const provider = providers[index]!;
    try {
      const contents = await provider.generate(request);
      if (validBatch(contents)) return { provider: provider.name, contents, failoverUsed: index > 0 };
    } catch {
      // Provider failures are intentionally opaque; the next configured adapter is tried.
    }
  }
  throw new Error("MARKETING_PROVIDER_UNAVAILABLE");
}
