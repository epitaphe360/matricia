import type{Benchmark,SolutionDecision,SolutionLevel,SolutionSet}from"./model";
export type Result<T>={status:"success";value:T}|{status:"error";reason:"UNAUTHENTICATED"|"INVALID_INPUT"|"UNAVAILABLE"|"FORBIDDEN"};
export type SolutionInsightsRepository={list():Promise<Result<{sets:SolutionSet[];benchmarks:Benchmark[]}>>;decide(input:{solutionSetId:string;level:SolutionLevel;decision:SolutionDecision;reason:string;deferredUntil:string|null;idempotencyKey:string;correlationId:string}):Promise<Result<Record<string,unknown>>>};
