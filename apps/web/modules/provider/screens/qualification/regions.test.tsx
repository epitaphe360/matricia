import { renderToStaticMarkup } from "react-dom/server";
import type { ComponentPropsWithoutRef } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh: vi.fn() }) }));
vi.mock("@/modules/shared/ui/button", () => ({ Button: ({ children, ...props }: ComponentPropsWithoutRef<"button">) => <button {...props}>{children}</button> }));
vi.mock("@/modules/shared/ui/label", () => ({ Label: ({ children, ...props }: ComponentPropsWithoutRef<"label">) => <label {...props}>{children}</label> }));
vi.mock("@/modules/shared/ui/textarea", () => ({ Textarea: (props: ComponentPropsWithoutRef<"textarea">) => <textarea {...props} /> }));

import { officialRegionCodes, providerRegionsInputSchema } from "@/modules/provider/data/qualification/regions";
import { declareProviderRegions, type ProviderActionState } from "./actions";
import { getProviderMessages } from "./messages";
import { RegionsForm } from "./regions-form";

const idle: ProviderActionState = { status: "idle" };
const org = "11111111-1111-4111-8111-111111111111";
const key = "33333333-3333-4333-8333-333333333333";

function form(codes: string[], reason = "Extension vers Rabat") {
  const data = new FormData();
  data.set("locale", "fr");
  data.set("organizationId", org);
  data.set("idempotencyKey", key);
  data.set("reason", reason);
  for (const code of codes) data.append("regionCodes", code);
  return data;
}

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id: "user-1" } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "PROVIDER_REGIONS_DECLARED", command_id: "44444444-4444-4444-8444-444444444444" }, error: null });
});

describe("régions d’intervention prestataire", () => {
  it("n’accepte que les codes officiels et dédoublonne", () => {
    const parsed = providerRegionsInputSchema.safeParse({ organizationId: org, regionCodes: ["CASABLANCA_SETTAT", "CASABLANCA_SETTAT", "RABAT_SALE_KENITRA"], reason: "Motif", idempotencyKey: key });
    expect(parsed.success && parsed.data.regionCodes).toEqual(["CASABLANCA_SETTAT", "RABAT_SALE_KENITRA"]);
    expect(providerRegionsInputSchema.safeParse({ organizationId: org, regionCodes: ["MA-01"], reason: "Motif", idempotencyKey: key }).success).toBe(false);
    expect(officialRegionCodes(["CASABLANCA", "SOUSS_MASSA"])).toEqual(["SOUSS_MASSA"]);
  });

  it("refuse une déclaration vide sans appeler le serveur", async () => {
    await expect(declareProviderRegions(idle, form([]))).resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("transmet les régions à la commande serveur", async () => {
    await expect(declareProviderRegions(idle, form(["CASABLANCA_SETTAT", "RABAT_SALE_KENITRA"]))).resolves.toEqual({ status: "success", outcome: "PROVIDER_REGIONS_DECLARED" });
    expect(mocks.rpc).toHaveBeenCalledWith("declare_provider_regions", { p_provider_organization_id: org, p_region_codes: ["CASABLANCA_SETTAT", "RABAT_SALE_KENITRA"], p_reason: "Extension vers Rabat", p_idempotency_key: key });
  });

  it("affiche les 12 régions en français, coche les régions actuelles", () => {
    const html = renderToStaticMarkup(<RegionsForm organizationId={org} locale="fr" messages={getProviderMessages("fr")} current={["SOUSS_MASSA"]} idempotencyKey={key} />);
    expect(html.match(/name="regionCodes"/g)).toHaveLength(12);
    expect(html).toContain("Régions d’intervention");
    expect(html).toContain("Souss-Massa");
    expect(html).toMatch(/checked="" value="SOUSS_MASSA"/);
    expect(html.match(/checked=""/g)).toHaveLength(1);
    expect(html).not.toContain("Aucune région déclarée");
  });

  it("signale l’absence de région et rend l’arabe", () => {
    const html = renderToStaticMarkup(<RegionsForm organizationId={org} locale="ar" messages={getProviderMessages("ar")} current={[]} idempotencyKey={key} />);
    expect(html).toContain("جهات التدخل");
    expect(html).toContain("سوس-ماسة");
    expect(html).toContain("لم تصرّح بأي جهة");
    expect(html).toContain("min-h-11");
  });
});
