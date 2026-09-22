import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ getUser: vi.fn(), rpc: vi.fn(), signInWithOtp: vi.fn() }));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({ auth: { getUser: mocks.getUser, signInWithOtp: mocks.signInWithOtp }, rpc: mocks.rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));

import {
  decideFranchiseProviderQualification,
  instructFranchiseDispute,
  inviteFranchiseMandateMember,
  proposeFranchiseVolumePurchase,
  upsertFranchiseAnomalyDefinition,
  upsertFranchiseRecommendationDefinition,
  upsertFranchiseRiskDefinition,
  type FranchiseCommandState,
} from "./commands";

const idle: FranchiseCommandState = { status: "idle" };
const id = "11111111-1111-4111-8111-111111111111";
const key = "22222222-2222-4222-8222-222222222222";

function form(values: Record<string, string>) {
  const data = new FormData();
  data.set("locale", "fr");
  data.set("idempotencyKey", key);
  data.set("correlationId", id);
  data.set("confirmed", "yes");
  for (const [name, value] of Object.entries(values)) data.set(name, value);
  return data;
}

beforeEach(() => {
  mocks.getUser.mockReset().mockResolvedValue({ data: { user: { id } } });
  mocks.rpc.mockReset().mockResolvedValue({ data: { outcome: "OK_DONE" }, error: null });
  mocks.signInWithOtp.mockReset().mockResolvedValue({ error: null });
});

describe("franchise remaining command actions", () => {
  it("enregistre une définition d’anomalie versionnée", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "ANOMALY_DEFINITION_UPSERTED" }, error: null });
    const result = await upsertFranchiseAnomalyDefinition(idle, form({
      libraryId: id,
      definitionKey: "HEALTH_SCORE_CRITICAL",
      severity: "CRITICAL",
      titleFr: "Score critique",
      titleAr: "درجة حرجة",
      descriptionFr: "Le score santé passe sous le seuil.",
      descriptionAr: "تنخفض درجة الصحة تحت العتبة.",
      blocking: "yes",
      evidenceRequired: "yes",
      changeReason: "Création initiale",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("upsert_franchise_anomaly_definition", expect.objectContaining({
      p_library_id: id,
      p_definition_key: "HEALTH_SCORE_CRITICAL",
      p_severity: "CRITICAL",
      p_blocking: true,
    }));
  });

  it("enregistre un modèle de risque versionné", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "RISK_DEFINITION_UPSERTED" }, error: null });
    const result = await upsertFranchiseRiskDefinition(idle, form({
      libraryId: id,
      definitionKey: "COVERAGE_GAP",
      impact: "HIGH",
      probability: "MEDIUM",
      titleFr: "Couverture insuffisante",
      titleAr: "تغطية غير كافية",
      descriptionFr: "Le réseau n’atteint pas le seuil.",
      descriptionAr: "لا تبلغ الشبكة العتبة.",
      changeReason: "Création initiale",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("upsert_franchise_risk_definition", expect.objectContaining({
      p_impact: "HIGH",
      p_probability: "MEDIUM",
    }));
  });

  it("associe une recommandation à un service de la bibliothèque", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "RECOMMENDATION_DEFINITION_UPSERTED" }, error: null });
    const result = await upsertFranchiseRecommendationDefinition(idle, form({
      libraryId: id,
      definitionKey: "BACKUP_MANAGED",
      serviceId: id,
      solutionLevel: "ADVANCED",
      priority: "10",
      titleFr: "Sauvegarde managée",
      titleAr: "نسخ مُدار",
      clientTextFr: "Mettre en place une sauvegarde suivie.",
      clientTextAr: "وضع نسخ احتياطي متابع.",
      technicalTextFr: "Activer le service volume-éligible.",
      technicalTextAr: "تفعيل الخدمة المؤهلة للحجم.",
      changeReason: "Association service",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("upsert_franchise_recommendation_definition", expect.objectContaining({
      p_service_id: id,
      p_solution_level: "ADVANCED",
      p_anomaly_definition_id: null,
    }));
  });

  it("instruit un incident ouvert sans l’ouvrir", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "FRANCHISE_DISPUTE_INSTRUCTED" }, error: null });
    const result = await instructFranchiseDispute(idle, form({
      disputeCaseId: id,
      statement: "Relance opérationnelle du prestataire sous 48 heures.",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("instruct_franchise_dispute", expect.objectContaining({
      p_dispute_case_id: id,
    }));
  });

  it("décide une qualification de service avec questionnaire soumis", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "PROVIDER_QUALIFICATION_DECIDED" }, error: null });
    const result = await decideFranchiseProviderQualification(idle, form({
      qualificationId: id,
      status: "APPROVED",
      questionnaireSessionId: id,
      scoreBasisPoints: "8000",
      rationale: "Dossier complet et contrôles passés.",
      ruleVersion: "QUAL-FR-001",
      mandatoryPassed: "yes",
      expectedRowVersion: "1",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("decide_provider_qualification", expect.objectContaining({
      p_qualification_id: id,
      p_status: "APPROVED",
      p_questionnaire_session_id: id,
      p_score_basis_points: 8000,
    }));
  });

  it("invite un utilisateur interne du mandat", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "INVITATION_CREATED" }, error: null });
    const result = await inviteFranchiseMandateMember(idle, form({
      organizationId: id,
      invitedEmail: "expert@example.invalid",
      roleCode: "FRANCHISE_EXPERT",
      expiryDays: "7",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("invite_organization_member_by_email", expect.objectContaining({
      p_organization_id: id,
      p_invited_email: "expert@example.invalid",
      p_role_codes: ["FRANCHISE_EXPERT"],
    }));
    expect(mocks.signInWithOtp).toHaveBeenCalledWith(expect.objectContaining({
      email: "expert@example.invalid",
      options: { shouldCreateUser: true, data: { locale: "fr" } },
    }));
  });

  it("propose un achat volume sans créer de contrat-cadre", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "FRANCHISE_VOLUME_PROPOSED" }, error: null });
    const result = await proposeFranchiseVolumePurchase(idle, form({
      libraryId: id,
      skuId: id,
      forecastUnits: "100",
      minimumCommitmentUnits: "20",
      maximumUnits: "200",
      paymentModel: "PAY_PER_USE",
      periodStart: "2026-10-01",
      periodEnd: "2027-03-31",
      rationale: "Prévision de consommation sur le SKU sauvegarde.",
    }));
    expect(result.status).toBe("success");
    expect(mocks.rpc).toHaveBeenCalledWith("propose_franchise_volume_purchase", expect.objectContaining({
      p_sku_id: id,
      p_payment_model: "PAY_PER_USE",
      p_forecast_units: 100,
    }));
  });

  it("refuse une invitation interne hors rôle franchise", async () => {
    const result = await inviteFranchiseMandateMember(idle, form({
      organizationId: id,
      invitedEmail: "admin@example.invalid",
      roleCode: "SUPER_ADMIN",
      expiryDays: "7",
    }));
    expect(result.status).toBe("error");
    if (result.status === "error") expect(result.reason).toBe("VALIDATION");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("refuse une qualification approuvée sans questionnaire soumis", async () => {
    const result = await decideFranchiseProviderQualification(idle, form({
      qualificationId: id,
      status: "APPROVED",
      ruleVersion: "QUAL-FR-001",
      rationale: "Dossier incomplet.",
      mandatoryPassed: "no",
      expectedRowVersion: "1",
    }));
    expect(result.status).toBe("error");
    if (result.status === "error") expect(result.reason).toBe("VALIDATION");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
