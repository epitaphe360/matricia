type RpcResult={data:unknown;error:null|{code?:string;message?:string}};
export type FollowupRpcClient={rpc(name:string,parameters?:Record<string,unknown>):PromiseLike<RpcResult>};
type ClaimedJob={id:string};

function claimedJobs(value:unknown):ClaimedJob[]{
 if(!Array.isArray(value))throw new Error("FRANCHISE_FOLLOWUP_CLAIM_INVALID");
 return value.map((row)=>{if(!row||typeof row!=="object"||typeof(row as{ id?:unknown }).id!=="string")throw new Error("FRANCHISE_FOLLOWUP_CLAIM_INVALID");return{id:(row as{id:string}).id}});
}

export function createFranchiseFollowupScheduler(client:FollowupRpcClient,workerId:string){
 let running=false;
 return async()=>{if(running)return;running=true;try{
  const scheduled=await client.rpc("schedule_franchise_followups",{p_limit:100});
  if(scheduled.error)throw new Error("FRANCHISE_FOLLOWUP_SCHEDULE_FAILED");
  const claim=await client.rpc("claim_franchise_followup_jobs",{p_worker_id:workerId,p_limit:25});
  if(claim.error)throw new Error("FRANCHISE_FOLLOWUP_CLAIM_FAILED");
  for(const job of claimedJobs(claim.data)){
   const completed=await client.rpc("complete_franchise_followup_job",{p_job_id:job.id,p_worker_id:workerId});
   if(completed.error){const failed=await client.rpc("fail_franchise_followup_job",{p_job_id:job.id,p_worker_id:workerId,p_error_code:"FOLLOWUP_QUEUE_FAILED"});if(failed.error)throw new Error("FRANCHISE_FOLLOWUP_FAILURE_RECORD_FAILED");}
  }
 }finally{running=false;}};
}
