import { describe,expect,it,vi } from "vitest";
vi.mock("@/modules/shared/lib/supabase/server",()=>({getSupabaseServerClient:vi.fn()}));
import { validPortfolioTenantPayload } from "./server-repository";

const a="00000000-0000-4000-8000-000000000001",b="00000000-0000-4000-8000-000000000002";
const project={id:"00000000-0000-4000-8000-000000000011",organization_id:a};
const contract={id:"00000000-0000-4000-8000-000000000012",client_organization_id:a};
const link={organization_id:a,project_id:project.id,contract_id:contract.id};
const event={organization_id:a,project_id:project.id};

describe("client portfolio tenant payload",()=>{
  it("accepts a fully coherent payload",()=>expect(validPortfolioTenantPayload([a],[project],[contract],[link],[event])).toBe(true));
  it("fails closed on a foreign contract, link or calendar row",()=>{
    expect(validPortfolioTenantPayload([a],[project],[{...contract,client_organization_id:b}],[link],[event])).toBe(false);
    expect(validPortfolioTenantPayload([a],[project],[contract],[{...link,organization_id:b}],[event])).toBe(false);
    expect(validPortfolioTenantPayload([a],[project],[contract],[link],[{...event,organization_id:b}])).toBe(false);
  });
  it("fails closed when link or calendar project ownership is inconsistent",()=>{
    const foreignProject={...project,id:"00000000-0000-4000-8000-000000000013",organization_id:b};
    expect(validPortfolioTenantPayload([a],[project],[contract],[{...link,project_id:foreignProject.id}],[])).toBe(false);
    expect(validPortfolioTenantPayload([a],[project],[contract],[link],[{...event,project_id:foreignProject.id}])).toBe(false);
  });
});
