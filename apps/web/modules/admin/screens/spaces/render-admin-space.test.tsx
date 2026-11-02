import type{ReactNode}from"react";
import{renderToStaticMarkup}from"react-dom/server";
import{beforeEach,describe,expect,it,vi}from"vitest";
const m=vi.hoisted(()=>({load:vi.fn(),queue:vi.fn()}));
vi.mock("next/navigation",()=>({redirect:(url:string)=>{throw Error(`REDIRECT:${url}`);},notFound:()=>{throw Error("NOT_FOUND");}}));
vi.mock("@/modules/admin/data/spaces/context",()=>({resolveAdminSpace:async()=>({status:"success",selectedQuery:"?organizationId=11111111-1111-4111-8111-111111111111",selectedOrganizationId:"11111111-1111-4111-8111-111111111111",userEmail:"operator@example.invalid"})}));
vi.mock("@/modules/admin/data/spaces/space-data",()=>({loadAdminSpaceSnapshot:m.load,findSpaceRow:()=>null}));
vi.mock("./queue-kit",()=>({SpaceQueueBoard:m.queue,SpaceHeaderActions:()=>null,SpaceCompareBoard:()=>null,SpaceDecisionBoard:()=>null,SpaceDetailBoard:()=>null,SpaceWizardBoard:()=>null}));
vi.mock("@/modules/admin/ui/admin-app-shell",()=>({AdminAppShell:({children,alternateHref}:{children:ReactNode;alternateHref:string})=><section><a href={alternateHref}>Language</a>{children}</section>,AdminCrumb:()=>null}));
import{renderAdminSpacePage}from"./render-admin-space";
const snapshot={rows:[],treat:[],supervision:null,providers:null,governance:null};
beforeEach(()=>{vi.clearAllMocks();m.queue.mockImplementation(()=><p>EMPTY_QUEUE_ZERO_COUNT</p>);});
describe("Admin generic route states",()=>{
 it.each(["diagnostics","demandes","matching","devis","contrats","avenants","missions","jalons","messagerie"])("never renders a false empty %s queue after failure",async space=>{m.load.mockResolvedValue({...snapshot,reason:"UNAVAILABLE"});const html=renderToStaticMarkup(await renderAdminSpacePage({locale:"fr",space,q:"texte",vue:"OPEN"}));expect(m.queue).not.toHaveBeenCalled();expect(html).not.toContain("EMPTY_QUEUE_ZERO_COUNT");expect(html).toContain("Chargement indisponible");expect(html).toContain("q=texte&amp;vue=OPEN");});
 it.each(["fr","ar"])("shows a safe forbidden state in %s",async locale=>{m.load.mockResolvedValue({...snapshot,reason:"FORBIDDEN"});const html=renderToStaticMarkup(await renderAdminSpacePage({locale,space:"providers"}));expect(m.queue).not.toHaveBeenCalled();expect(html).not.toContain("FORBIDDEN");expect(html).toContain(locale==="ar"?"الوصول غير مسموح":"Accès non autorisé");});
 it("renders the actual successful empty state",async()=>{m.load.mockResolvedValue({...snapshot,reason:null});expect(renderToStaticMarkup(await renderAdminSpacePage({locale:"fr",space:"diagnostics"}))).toContain("EMPTY_QUEUE_ZERO_COUNT");});
 it("redirects authentication loss without fabricating a queue",async()=>{m.load.mockResolvedValue({...snapshot,reason:"UNAUTHENTICATED"});await expect(renderAdminSpacePage({locale:"ar",space:"diagnostics",q:"texte"})).rejects.toThrow("REDIRECT:");expect(m.queue).not.toHaveBeenCalled();});
 it("labels auxiliary details partial while keeping the successful queue",async()=>{m.load.mockResolvedValue({...snapshot,reason:null,detailsReason:"UNAVAILABLE"});const html=renderToStaticMarkup(await renderAdminSpacePage({locale:"fr",space:"providers"}));expect(html).toContain("EMPTY_QUEUE_ZERO_COUNT");expect(html).toContain("Certains détails sont indisponibles");});
});
