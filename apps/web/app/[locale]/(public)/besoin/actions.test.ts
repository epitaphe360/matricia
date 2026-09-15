import { beforeEach,describe,expect,it,vi } from "vitest";
const {rpc,revalidatePath}=vi.hoisted(()=>({rpc:vi.fn(),revalidatePath:vi.fn()}));
vi.mock("@/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({rpc})}));
vi.mock("next/cache",()=>({revalidatePath}));
import { savePublicNeedIntake } from "./actions";

const organizationId="00000000-0000-4000-8000-000000000001",intakeId="00000000-0000-4000-8000-000000000002";
function form(payload:unknown={need:"Sécuriser le réseau du bureau",location:"Casablanca",timing:"Ce trimestre",constraints:"Accès en soirée"}){const data=new FormData();data.set("locale","fr");data.set("organizationId",organizationId);data.set("payload",JSON.stringify(payload));return data}
describe("savePublicNeedIntake",()=>{
  beforeEach(()=>vi.clearAllMocks());
  it("rejects invalid input before the RPC",async()=>{await expect(savePublicNeedIntake({status:"idle"},form({need:"court",location:"",timing:"",constraints:""}))).resolves.toEqual({status:"error",reason:"VALIDATION"});expect(rpc).not.toHaveBeenCalled()});
  it("persists through the guarded RPC",async()=>{rpc.mockResolvedValue({data:{outcome:"PUBLIC_NEED_INTAKE_SAVED",intake_id:intakeId,status:"DRAFT_REVIEW"},error:null});await expect(savePublicNeedIntake({status:"idle"},form())).resolves.toEqual({status:"success",intakeId});expect(rpc).toHaveBeenCalledWith("save_public_need_intake",expect.objectContaining({p_organization_id:organizationId,p_locale:"fr",p_idempotency_key:expect.stringMatching(/^[0-9a-f]{64}$/u)}));expect(revalidatePath).toHaveBeenCalledWith("/fr/client/demandes")});
  it("maps a tenant denial without exposing details",async()=>{rpc.mockResolvedValue({data:null,error:{code:"42501"}});await expect(savePublicNeedIntake({status:"idle"},form())).resolves.toEqual({status:"error",reason:"FORBIDDEN"})});
});
