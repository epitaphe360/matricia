import { describe, expect, it, vi } from "vitest";
const mocks=vi.hoisted(()=>({request:vi.fn(),rpc:vi.fn()}));
vi.mock("next/cache",()=>({revalidatePath:vi.fn()}));
vi.mock("@/modules/shared/lib/supabase/server",()=>({getSupabaseServerClient:async()=>({rpc:mocks.rpc})}));
vi.mock("@/modules/admin/screens/command-center/actions",()=>({requestAdminAction:mocks.request}));
vi.mock("@/app/[locale]/invitations/actions",()=>({createInvitation:vi.fn()}));
import { requestActorMutation } from "./actor-actions";
import { organizationRoleGates } from "@/modules/admin/data/spaces/role-preview";
describe("droits canoniques",()=>{
 it("montre l’effet du changement OWNER vers VIEWER sans privilège plateforme",()=>{
  expect(organizationRoleGates("CLIENT_OWNER")).toContain("CLIENT_REQUEST_MANAGE");
  expect(organizationRoleGates("CLIENT_VIEWER")).not.toContain("CLIENT_REQUEST_MANAGE");
  expect(organizationRoleGates("CLIENT_OWNER")).not.toContain("PLATFORM_ADMINISTRATION");
 });
 it("refuse une capacité hors modèle avant tout appel",async()=>{
  const f=new FormData();f.append("capabilities","SUPER_ADMIN_BYPASS");
  expect(await requestActorMutation({status:"idle"},f)).toEqual({status:"error",reason:"VALIDATION"});
  expect(mocks.request).not.toHaveBeenCalled();expect(mocks.rpc).not.toHaveBeenCalled();
 });
});
