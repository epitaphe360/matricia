import type { DisputeDetail,DisputeSummary,MissionOption } from "./model";
export type Failure="UNAUTHENTICATED"|"FORBIDDEN"|"INVALID_INPUT"|"INVALID_RESPONSE"|"UNAVAILABLE";
export type Result<T>={status:"success";value:T}|{status:"error";reason:Failure};
export type DisputesRepository={
 list():Promise<Result<{cases:DisputeSummary[];missions:MissionOption[]}>>;
 detail(id:string):Promise<Result<DisputeDetail|null>>;
 command(name:string,input:Record<string,unknown>):Promise<Result<Record<string,unknown>>>;
};
