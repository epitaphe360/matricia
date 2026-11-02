import { describe,expect,it } from "vitest";
import { amendmentExecutionSchema,readAmendmentExecutions } from "./amendment-execution";
const id=(n:number)=>`e1000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
describe("signed amendment preparation",()=>{
 it("does not accept ready-to-execute state without the exact signed criteria",()=>{expect(amendmentExecutionSchema.safeParse({amendment_id:id(1),status:"READY",items:[{key:"REPORT",label_fr:"Rapport",label_ar:"تقرير"}],can_apply:true}).success).toBe(false)});
 it("keeps incomplete legacy source explicit instead of manufacturing criteria",()=>{expect(amendmentExecutionSchema.safeParse({amendment_id:id(1),status:"MISSING_SIGNED_CRITERIA",items:[{key:"REPORT",label_fr:"Rapport",label_ar:"تقرير",criteria:null}],can_apply:true}).success).toBe(true)});
 it("does not mistake a governed scope exception for an empty or applied preparation",()=>{const result=amendmentExecutionSchema.parse({amendment_id:id(1),status:"SCOPE_RECONCILIATION_REQUIRED",items:[],can_apply:true});expect(result.status).toBe("SCOPE_RECONCILIATION_REQUIRED")});
 it("keeps an outage unavailable instead of reporting the work applied",async()=>{const values=await readAmendmentExecutions([id(1)],async()=>({data:null,error:{code:"UNAVAILABLE"}}));expect(values.has(id(1))).toBe(false)});
 it("rejects a batch containing an unrelated amendment",async()=>{const values=await readAmendmentExecutions([id(1)],async()=>({data:[{amendment_id:id(2),status:"APPLIED",items:[],can_apply:false}],error:null}));expect(values.size).toBe(0)});
 it("reads more than 100 preparations using bounded authenticated batches",async()=>{const ids=Array.from({length:101},(_,n)=>id(n+1)),sizes:number[]=[];const values=await readAmendmentExecutions(ids,async batch=>{sizes.push(batch.length);return{data:batch.map(id=>({amendment_id:id,status:"APPLIED",items:[],can_apply:false})),error:null}});expect(values.size).toBe(101);expect(sizes).toEqual([100,1])});
});
