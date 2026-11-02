import { z } from "zod";
const uuid = z.string().uuid();
export const qualificationReviewQuestion = z.object({
  id: uuid, labelFr: z.string(), labelAr: z.string(), answerType: z.string(),
  options: z.unknown(), required: z.boolean(), applicable: z.boolean(), answered: z.boolean(),
  value: z.unknown(), answeredAt: z.string().nullable(),
});
export const qualificationReviewSession = z.object({
  id: uuid, titleFr: z.string(), titleAr: z.string(), version: z.number().int().positive(),
  submittedAt: z.string(), locale: z.enum(["fr-MA", "ar-MA"]),
  engineScoreBasisPoints: z.number().int().min(0).max(10000),
  snapshotHash: z.string().regex(/^[a-f0-9]{64}$/u), answerManifestHash: z.string().regex(/^[a-f0-9]{64}$/u),
  contextHash: z.string().regex(/^[a-f0-9]{64}$/u), questions: z.array(qualificationReviewQuestion),
});
export const qualificationReviewContext = z.object({
  qualificationId: uuid, organizationId: uuid, serviceId: uuid, libraryId: uuid,
  qualificationRowVersion: z.number().int().positive(),
  sessions: z.array(z.object({id:uuid,titleFr:z.string(),titleAr:z.string(),version:z.number().int().positive(),submittedAt:z.string(),available:z.boolean()})),
  total: z.number().int().nonnegative(), page: z.number().int().positive(), pageSize: z.literal(20),
  selected: qualificationReviewSession.nullable(),
});
export type QualificationReviewContext = z.infer<typeof qualificationReviewContext>;
export type QualificationReviewSession = z.infer<typeof qualificationReviewSession>;
export type QualificationReviewQuestion = z.infer<typeof qualificationReviewQuestion>;
export type QualificationReviewReadResult = {status:"success";context:QualificationReviewContext}|{status:"error";reason:"UNAUTHENTICATED"|"MFA_REQUIRED"|"FORBIDDEN"|"UNAVAILABLE"|"VALIDATION"};
export function qualificationScorePercent(basis:number):string {
  if(!Number.isInteger(basis)||basis<0||basis>10000)throw new Error("INVALID_QUALIFICATION_SCORE");
  const fraction=String(basis%100).padStart(2,"0").replace(/0+$/u,"");
  return `${Math.trunc(basis/100)}${fraction?`.${fraction}`:""}`;
}
export function reviewAnswerText(question:QualificationReviewQuestion,locale:"fr"|"ar"):string {
  if(!question.answered)return locale==="ar"?"لم تُقدّم إجابة":"Aucune réponse déposée";
  const value=question.value;
  if(typeof value==="boolean")return locale==="ar"?(value?"نعم":"لا"):(value?"Oui":"Non");
  if(typeof value==="string"){
    if(["SINGLE_SELECT","MULTI_SELECT","SELECT","RADIO","DROPDOWN"].includes(question.answerType)){
      const options=Array.isArray(question.options)?question.options:[];
      const selected=options.find((option:unknown)=>typeof option==="object"&&option!==null&&"value"in option&&option.value===value)as Record<string,unknown>|undefined;
      const label=selected?.[locale==="ar"?"label_ar":"label_fr"];
      if(typeof label==="string")return label;
    }
    return value;
  }
  return JSON.stringify(value,null,2)??(locale==="ar"?"قيمة فارغة":"Valeur vide");
}

export function qualificationDecisionStates(current:string):string[]{
 if(["NOT_REQUESTED","PENDING"].includes(current))return["INFORMATION_REQUIRED","APPROVED","CONDITIONAL","REJECTED"];
 if(["APPROVED","CONDITIONAL"].includes(current))return["PENDING","SUSPENDED","EXPIRED"];
 if(["INFORMATION_REQUIRED","SUSPENDED","EXPIRED","REJECTED"].includes(current))return["PENDING"];
 return[];
}
