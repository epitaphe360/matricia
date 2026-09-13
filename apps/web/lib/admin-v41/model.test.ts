import { describe,expect,it } from "vitest";
import { adminV41Modules,adminV41OverviewSchema } from "./model";

describe("admin V4.1 overview",()=>{
 it("requires every bounded operational module and three separated flows",()=>{
  const modules=adminV41Modules.map(key=>({key,open:0,exceptions:0}));
  expect(adminV41OverviewSchema.parse({generated_at:"2026-09-13T10:00:00.000Z",limit:50,financial_flows:{client_to_provider_declared:1,matricia_own_revenue:2,provider_commission_receipts:3},modules}).modules).toHaveLength(13);
 });
 it("rejects negative or partial projections",()=>{
  expect(adminV41OverviewSchema.safeParse({generated_at:"2026-09-13T10:00:00.000Z",limit:50,financial_flows:{client_to_provider_declared:-1,matricia_own_revenue:0,provider_commission_receipts:0},modules:[]}).success).toBe(false);
 });
});
