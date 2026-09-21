import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({ getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser }, rpc: mocks.rpc }) }));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import { importFranchiseProviders, inviteFranchiseProvider, recordFranchiseFolderActivity, advanceFranchiseFolderPipeline, type FranchiseInviteState } from "./actions";

const idle: FranchiseInviteState = { status: "idle" };
const id = "11111111-1111-4111-8111-111111111111";
const key = "22222222-2222-4222-8222-222222222222";

function form() {
  const value = new FormData();
  value.set("locale", "fr");
  value.set("franchiseId", id);
  value.set("territoryVersionId", id);
  value.set("ownerUserId", id);
  value.set("idempotencyKey", key);
  return value;
}

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "FRANCHISE_PROSPECT_SAVED", prospect_id: id }, error: null });
});

describe("franchise provider invitations", () => {
  it("crée un prospect PROVIDER puis consigne une activité INVITATION", async () => {
    const value = form();
    value.set("displayName", "Studio Atlas");
    value.set("contactEmail", "atlas@example.invalid");
    value.set("organizationName", "Atlas");
    value.set("sourceCode", "INVITE");
    const result = await inviteFranchiseProvider(idle, value);
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("save_franchise_prospect", expect.objectContaining({
      p_prospect_type: "PROVIDER",
      p_display_name: "Studio Atlas",
      p_contact_email: "atlas@example.invalid",
      p_source_code: "INVITE",
    }));
    expect(mocks.rpc).toHaveBeenCalledWith("record_franchise_activity", expect.objectContaining({
      p_prospect_id: id,
      p_activity_type: "INVITATION",
    }));
  });

  it("importe un CSV dans le périmètre du mandat", async () => {
    const value = form();
    value.set("csvText", "nom,courriel,organisation\nStudio Atlas,atlas@example.invalid,Atlas");
    const result = await importFranchiseProviders(idle, value);
    expect(result.status).toBe("success");
    if (result.status === "success") expect(result.created).toBe(1);
    expect(mocks.rpc).toHaveBeenCalledWith("save_franchise_prospect", expect.objectContaining({
      p_source_code: "CSV_IMPORT",
      p_prospect_type: "PROVIDER",
    }));
  });

  it("crée un prospect CLIENT puis consigne une invitation", async () => {
    const value = form();
    value.set("displayName", "Conseil stratégique");
    value.set("contactEmail", "client@example.invalid");
    value.set("organizationName", "Conseil");
    value.set("sourceCode", "INVITE");
    value.set("prospectType", "CLIENT");
    const result = await inviteFranchiseProvider(idle, value);
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("save_franchise_prospect", expect.objectContaining({
      p_prospect_type: "CLIENT",
      p_display_name: "Conseil stratégique",
    }));
  });

  it("consigne une activité de dossier et avance le pipeline du mandat", async () => {
    const activity = form();
    activity.set("prospectId", id);
    activity.set("activityType", "NOTE");
    activity.set("occurredAt", "2026-09-21T10:00:00.000Z");
    activity.set("summary", "Pièce reçue");
    activity.set("evidenceReference", "doc://rc");
    const recorded = await recordFranchiseFolderActivity(idle, activity);
    expect(recorded.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("record_franchise_activity", expect.objectContaining({
      p_prospect_id: id,
      p_activity_type: "NOTE",
      p_evidence_refs: [{ reference: "doc://rc" }],
    }));
    mocks.rpc.mockResolvedValue({ data: { outcome: "PIPELINE_ADVANCED", prospect_id: id }, error: null });
    const pipeline = form();
    pipeline.set("prospectId", id);
    pipeline.set("toStage", "OPENED");
    pipeline.set("reasonCode", "CONTACT_CONFIRMED");
    pipeline.set("rowVersion", "2");
    const advanced = await advanceFranchiseFolderPipeline(idle, pipeline);
    expect(advanced.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("advance_franchise_pipeline", expect.objectContaining({
      p_to_stage: "OPENED",
      p_expected_row_version: 2,
    }));
  });
});
