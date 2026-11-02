import type{SupabaseClient}from"@supabase/supabase-js";
/** One durable database page per cycle. The database owns locking and resume state. */
export function createProviderBillingScheduler(client:Pick<SupabaseClient,"rpc">){
 let running=false;
 return async()=>{if(running)return;running=true;try{const result=await client.rpc("run_provider_billing_scheduler_v1",{p_limit:100});if(result.error||result.data?.outcome!=="PROVIDER_BILLING_SCHEDULER_COMPLETED"&&result.data?.outcome!=="PROVIDER_BILLING_BUSY")throw new Error("PROVIDER_BILLING_SCHEDULER_FAILED");const reminders=await client.rpc("run_provider_billing_reminders_v1",{p_limit:100});if(reminders.error)throw new Error("PROVIDER_BILLING_REMINDERS_FAILED");}finally{running=false;}};
}
