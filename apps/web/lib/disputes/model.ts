import { z } from "zod";

export const uuidSchema=z.string().uuid();
export const hashSchema=z.string().regex(/^[0-9a-f]{64}$/u);
export const statusSchema=z.enum(["WARNING_LEVEL_1","PROVIDER_RESPONDED","MEDIATION_REVIEW","DECIDED","APPEALED","CLOSED"]);
export const evidenceTypeSchema=z.enum(["DOCUMENT","IMAGE","URL","MESSAGE","DELIVERY_PROOF","OTHER"]);
export const visibilitySchema=z.enum(["BOTH_PARTIES","CLIENT_ONLY","PROVIDER_ONLY","MEDIATOR_ONLY"]);
export const outcomeSchema=z.enum(["COMPLIANT","MINOR_CORRECTION","OUT_OF_SCOPE","CLIENT_ABUSE","MUTUAL_AGREEMENT","NON_COMPLIANT_CONFIRMED"]);

export type DisputeCapabilities={open:boolean;respond:boolean;decide:boolean;appeal:boolean;propose:boolean;approve:boolean;activate:boolean};
export type MissionOption={id:string;status:string};
export type Evidence={id:string;type:z.infer<typeof evidenceTypeSchema>;statement:string|null;url:string|null;visibility:z.infer<typeof visibilitySchema>;hash:string;createdAt:string};
export type TimelineEvent={id:string;type:string;from:string|null;to:string;createdAt:string};
export type Reassignment={id:string;key:string;status:string;originalCostMinor:string;proposedCostMinor:string|null;costDeltaMinor:string|null;currency:string;rowVersion:number};
export type DisputeSummary={id:string;missionId:string;obligationKey:string;description:string;urgency:"STANDARD"|"URGENT";status:z.infer<typeof statusSchema>;responseDueAt:string;reviewDueAt:string|null;appealDueAt:string|null;rowVersion:number};
export type DisputeDetail=DisputeSummary&{clientOrganizationId:string;providerOrganizationId:string;policyVersion:string;evidence:Evidence[];events:TimelineEvent[];reassignment:Reassignment|null;capabilities:DisputeCapabilities};

export function moneyToMinor(value:string):string|null{const normalized=value.trim().replace(/\s/gu,"").replace(",",".");if(!/^\d+(?:\.\d{1,2})?$/u.test(normalized))return null;const[whole,fraction=""]=normalized.split(".");return(BigInt(whole)*BigInt(100)+BigInt(fraction.padEnd(2,"0"))).toString();}
export function evidenceItem(statement:string,hash:string,visibility:string,type:string="MESSAGE"){return{type:evidenceTypeSchema.parse(type),statement:statement.trim(),hash:hashSchema.parse(hash),visibility:visibilitySchema.parse(visibility),metadata:{}};}
