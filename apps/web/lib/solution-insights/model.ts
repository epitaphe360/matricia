import{z}from"zod";
export const uuid=z.string().uuid();
export const solutionLevel=z.enum(["ESSENTIAL","STANDARD","ADVANCED"]);
export const solutionDecision=z.enum(["ACCEPTED","REJECTED","DEFERRED"]);
export type SolutionLevel=z.infer<typeof solutionLevel>;
export type SolutionDecision=z.infer<typeof solutionDecision>;
export type SolutionOption={id:string;level:SolutionLevel;expectedScoreBps:number;estimatedAmountMinor:string|null;currency:string|null;benefits:unknown[];tradeoffs:unknown[];explanation:Record<string,unknown>};
export type SolutionSet={id:string;anomalyId:string;version:number;rationaleFr:string;rationaleAr:string;createdAt:string;options:SolutionOption[];decisions:{id:string;level:SolutionLevel;decision:SolutionDecision;reason:string;deferredUntil:string|null;decidedAt:string}[]};
export type Benchmark={id:string;metricCode:string;segmentKey:string;periodStart:string;periodEnd:string;groupSizeBand:string;roundedMean:string;publishedAt:string};
export function formatMinorExact(value:string,currency:string,locale:"fr"|"ar"){const tag=locale==="ar"?"ar-MA":"fr-MA",formatter=new Intl.NumberFormat(tag,{style:"currency",currency}),digits=formatter.resolvedOptions().maximumFractionDigits??2,scale=BigInt(10)**BigInt(digits),amount=BigInt(value),whole=amount/scale,fraction=(amount%scale).toString().padStart(digits,"0"),integer=new Intl.NumberFormat(tag,{maximumFractionDigits:0}).format(whole);return formatter.formatToParts(0).map(part=>part.type==="integer"?integer:part.type==="fraction"?fraction:part.value).join("")}
