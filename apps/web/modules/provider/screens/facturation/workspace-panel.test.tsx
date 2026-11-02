import{describe,it,expect,vi}from"vitest";
import{renderToStaticMarkup}from"react-dom/server";
import{ProviderBillingWorkspace}from"./workspace-panel";
vi.mock("./workflow-form",()=>({FinanceDecisionForm:({operation}:{operation:string})=><form data-operation={operation}/>}));
const org="11111111-1111-4111-8111-111111111111",period="22222222-2222-4222-8222-222222222222",event="33333333-3333-4333-8333-333333333333";
const value={declarations:[],decisions:[],periods:[{id:period,period_end:"2026-10-31",dispute_until:"2099-01-01T00:00:00Z",currency:"TND",provider_organization_id:org}],lines:[{period_id:period,payable_event_id:event,source_snapshot:{mission_id:event,contract_version_id:event,event_type:"CLIENT_RECEIPT_CONFIRMED",gross_amount_minor:"123456789012345678",commission_basis_points:1000,commission_amount_minor:"12345678901234568",tax_amount_minor:"0",total_due_minor:"12345678901234568",client_receipt_reference:"CLIENT-INV-42",currency:"TND",occurred_on:"2026-10-20"}}],disputes:[],resolutions:[],completions:[],exceptions:[]};
describe("contradictory provider statements",()=>{
 it("shows immutable commission facts and a line-specific dispute instead of manufacturing an invoice",()=>{const html=renderToStaticMarkup(<ProviderBillingWorkspace value={value} locale="fr" organizationId={org}/>);expect(html).toContain("CLIENT-INV-42");expect(html).toContain("Base commissionnable");expect(html).toContain('data-operation="dispute"');expect(html).toContain("12.345.678.901.234,568");expect(html).not.toContain("Émettre une facture");});
 it("preserves Arabic facts and suppresses new disputes once the period is closed",()=>{const html=renderToStaticMarkup(<ProviderBillingWorkspace value={{...value,completions:[{period_id:period}]}} locale="ar"/>);expect(html).toContain("أغلقت الفترة");expect(html).not.toContain('data-operation="dispute"');});
});
