import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  rpc: vi.fn(),
  from: vi.fn(),
  storageFrom: vi.fn(),
  upload: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/modules/shared/lib/supabase/server", () => ({
  getSupabaseServerClient: async () => ({
    auth: { getUser: mocks.getUser }, rpc: mocks.rpc, from: mocks.from,
    storage: { from: mocks.storageFrom },
  }),
}));
vi.mock("@/modules/shared/lib/i18n/locale", () => ({ isLocale: (value: string) => value === "fr" || value === "ar" }));
vi.mock("next/cache", () => ({ revalidatePath: mocks.revalidatePath }));
vi.mock("node:crypto", () => ({
  randomUUID: () => "99999999-9999-4999-8999-999999999999",
  createHash: () => ({ update: () => ({ digest: () => "a".repeat(64) }) }),
}));

import {
  listClientOnboarding,
  saveClientProfile,
  submitClientCompliance,
  uploadClientComplianceDocument,
  respondClientComplianceQuestion,
  type DocumentUploadActionState,
  type ProfileActionState,
  type SubmitActionState,
  type QuestionResponseActionState,
} from "./actions";
import { getClientOnboardingMessages } from "./messages";

const userId = "11111111-1111-4111-8111-111111111111";
const organizationId = "22222222-2222-4222-8222-222222222222";
const membershipId = "33333333-3333-4333-8333-333333333333";
const caseId = "44444444-4444-4444-8444-444444444444";
const trialId = "55555555-5555-4555-8555-555555555555";
const idempotencyKey = "66666666-6666-4666-8666-666666666666";
const profileIdle: ProfileActionState = { status: "idle" };
const submitIdle: SubmitActionState = { status: "idle" };
const documentIdle: DocumentUploadActionState = { status: "idle" };
const documentId = "77777777-7777-4777-8777-777777777777";
const questionId = "88888888-8888-4888-8888-888888888888";
const questionIdle: QuestionResponseActionState = { status: "idle" };

function profileForm(overrides: Record<string, string> = {}) {
  const form = new FormData();
  const values = {
    organizationId,
    locale: "fr",
    idempotencyKey,
    legalForm: "SARL",
    incorporationDate: "2020-02-20",
    activity: "Conseil aux entreprises",
    sector: "Services professionnels",
    employeeCount: "12",
    registeredCity: "Casablanca",
    addressLine1: "10 rue Exemple",
    postalCode: "20000",
    contactPhone: "+212522000001",
    contactEmail: "CONTACT@EXAMPLE.INVALID",
    representativeFirstName: "Amal",
    representativeLastName: "Alami",
    representativeTitle: "Gérante",
    representativeEmail: "AMAL@EXAMPLE.INVALID",
    representativePhone: "+212600000001",
    representativePower: "Gérante statutaire",
    ifNumber: "IF-A-001",
    rcNumber: "RC-A-001",
    website: "https://example.invalid",
    accuracyConfirmed: "yes",
    representationAuthorized: "yes",
    ...overrides,
  };
  for (const [key, value] of Object.entries(values)) form.set(key, value);
  return form;
}

function submitForm(overrides: Record<string, string> = {}) {
  const form = new FormData();
  const values = { complianceCaseId: caseId, locale: "ar", idempotencyKey, confirmed: "yes", ...overrides };
  for (const [key, value] of Object.entries(values)) form.set(key, value);
  return form;
}

function documentForm(file: File, overrides: Record<string, string> = {}) {
  const form = new FormData();
  const values = {
    complianceCaseId: caseId, locale: "fr", idempotencyKey,
    documentType: "REGISTRATION_DOCUMENT", documentNumber: "RC-2026-01",
    issuer: "Tribunal de commerce", issuedOn: "2026-09-01", expiresOn: "",
    ...overrides,
  };
  for (const [key, value] of Object.entries(values)) form.set(key, value);
  form.set("file", file);
  return form;
}

function responseForm(overrides: Record<string, string> = {}) {
  const form = new FormData();
  const values = { questionId, locale: "ar", idempotencyKey, responseText: "Voici la correction administrative demandée.", ...overrides };
  for (const [key, value] of Object.entries(values)) form.set(key, value);
  return form;
}

const pdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37]);
const pngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);

function query(result: { data: unknown; error: unknown }) {
  const chain: Record<string, unknown> = {};
  for (const method of ["eq", "in", "order"]) chain[method] = vi.fn(() => chain);
  chain.then = (resolve: (value: unknown) => unknown) => Promise.resolve(result).then(resolve);
  return chain;
}

describe("Client onboarding mutations", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getUser.mockResolvedValue({ data: { user: { id: userId } }, error: null });
    mocks.storageFrom.mockReturnValue({ upload: mocks.upload });
    mocks.upload.mockResolvedValue({ data: { path: "ignored" }, error: null });
  });

  it("valide le profil et les déclarations avant toute lecture Auth", async () => {
    await expect(saveClientProfile(profileIdle, profileForm({ accuracyConfirmed: "no", contactEmail: "invalid" })))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("enregistre une version par RPC avec idempotence, corrélation et payload borné", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "CLIENT_PROFILE_VERSION_CREATED", profile_version: 2, internal: "ignored" }, error: null });
    await expect(saveClientProfile(profileIdle, profileForm())).resolves.toEqual({ status: "success", profileVersion: 2 });
    expect(mocks.rpc).toHaveBeenCalledWith("save_client_profile_draft", {
      p_organization_id: organizationId,
      p_idempotency_key: idempotencyKey,
      p_correlation_id: "99999999-9999-4999-8999-999999999999",
      p_profile: expect.objectContaining({
        legal_form: "SARL",
        employee_count: 12,
        contact: { phone: "+212522000001", email: "contact@example.invalid" },
        declarations: { accuracy_confirmed: true, representation_authorized: true },
      }),
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/fr/client/onboarding");
  });

  it("neutralise une erreur RPC sans exposer le diagnostic interne", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "IDENTIFIER_CHANGE_REQUIRES_REVIEW secret" } });
    const result = await saveClientProfile(profileIdle, profileForm());
    expect(result).toEqual({ status: "error", reason: "UNAVAILABLE" });
    expect(JSON.stringify(result)).not.toContain("IDENTIFIER");
    expect(JSON.stringify(result)).not.toContain("secret");
  });

  it("exige une confirmation avant soumission", async () => {
    await expect(submitClientCompliance(submitIdle, submitForm({ confirmed: "no" })))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
  });

  it("soumet le dossier par le RPC durci 026", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "CLIENT_COMPLIANCE_SUBMITTED", status: "UNDER_REVIEW" }, error: null });
    await expect(submitClientCompliance(submitIdle, submitForm())).resolves.toEqual({ status: "success" });
    expect(mocks.rpc).toHaveBeenCalledWith("submit_client_compliance", {
      p_compliance_case_id: caseId,
      p_idempotency_key: idempotencyKey,
      p_correlation_id: "99999999-9999-4999-8999-999999999999",
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/ar/client/onboarding");
  });

  it("refuse les réponses RPC inattendues", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "INTERNAL_STATE", status: "VERIFIED" }, error: null });
    await expect(submitClientCompliance(submitIdle, submitForm())).resolves.toEqual({ status: "error", reason: "UNAVAILABLE" });
  });

  it("valide taille, MIME et extension du justificatif avant Auth", async () => {
    const invalid = new File([new Uint8Array([1])], "preuve.exe", { type: "application/pdf" });
    await expect(uploadClientComplianceDocument(documentIdle, documentForm(invalid)))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
    expect(mocks.storageFrom).not.toHaveBeenCalled();
  });

  it("réserve, téléverse en privé puis finalise sans divulguer le chemin", async () => {
    const file = new File([pdfBytes], "registre.pdf", { type: "application/pdf" });
    mocks.rpc
      .mockResolvedValueOnce({ data: { outcome: "DOCUMENT_UPLOAD_RESERVED", document_id: documentId, version: 2, bucket: "client-compliance", object_path: `${organizationId}/${documentId}/registre.pdf`, status: "UPLOAD_PENDING" }, error: null })
      .mockResolvedValueOnce({ data: { outcome: "DOCUMENT_UPLOADED", status: "PENDING_REVIEW", document_id: documentId }, error: null });
    const result = await uploadClientComplianceDocument(documentIdle, documentForm(file));
    expect(mocks.rpc).toHaveBeenNthCalledWith(1, "begin_client_compliance_document_upload", expect.objectContaining({
      p_compliance_case_id: caseId, p_document_type: "REGISTRATION_DOCUMENT", p_size_bytes: pdfBytes.length,
      p_mime_type: "application/pdf", p_sha256: "a".repeat(64), p_idempotency_key: idempotencyKey,
    }));
    expect(mocks.storageFrom).toHaveBeenCalledWith("client-compliance");
    expect(mocks.upload).toHaveBeenCalledWith(`${organizationId}/${documentId}/registre.pdf`, expect.any(Buffer), {
      contentType: "application/pdf", upsert: false,
    });
    expect(mocks.rpc).toHaveBeenNthCalledWith(2, "finalize_client_compliance_document_upload", {
      p_document_id: documentId,
      p_idempotency_key: `${idempotencyKey}:finalize`,
      p_correlation_id: "99999999-9999-4999-8999-999999999999",
    });
    expect(result).toEqual({ status: "success", documentType: "REGISTRATION_DOCUMENT", version: 2 });
    expect(JSON.stringify(result)).not.toContain(documentId);
    expect(JSON.stringify(result)).not.toContain(organizationId);
  });

  it("ne finalise pas si Storage refuse le téléversement", async () => {
    const file = new File([pngBytes], "registre.png", { type: "image/png" });
    mocks.rpc.mockResolvedValueOnce({ data: { outcome: "DOCUMENT_UPLOAD_RESERVED", document_id: documentId, version: 1, bucket: "client-compliance", object_path: "private/path.png", status: "UPLOAD_PENDING" }, error: null });
    mocks.upload.mockResolvedValue({ data: null, error: { statusCode: "500", message: "private/path.png" } });
    const result = await uploadClientComplianceDocument(documentIdle, documentForm(file));
    expect(result).toEqual({ status: "error", reason: "UPLOAD" });
    expect(mocks.rpc).toHaveBeenCalledTimes(1);
    expect(JSON.stringify(result)).not.toContain("private");
  });

  it("refuse un fichier dépassant la politique de 10 Mo", async () => {
    const file = new File([new Uint8Array(10_485_761)], "registre.pdf", { type: "application/pdf" });
    await expect(uploadClientComplianceDocument(documentIdle, documentForm(file)))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
  });

  it.each([
    ["faux.pdf", "application/pdf", new Uint8Array([0x4d, 0x5a, 0x90])],
    ["faux.jpg", "image/jpeg", pngBytes],
    ["faux.png", "image/png", pdfBytes],
  ])("refuse le contenu falsifié %s malgré MIME et extension valides", async (name, mimeType, bytes) => {
    const file = new File([bytes], name, { type: mimeType });
    await expect(uploadClientComplianceDocument(documentIdle, documentForm(file)))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).toHaveBeenCalledOnce();
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.storageFrom).not.toHaveBeenCalled();
  });

  it("exige un numéro de document d’au moins deux caractères avant Auth", async () => {
    const file = new File([pdfBytes], "registre.pdf", { type: "application/pdf" });
    await expect(uploadClientComplianceDocument(documentIdle, documentForm(file, { documentNumber: "X" })))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
  });

  it("ne lit jamais les octets du fichier d’un utilisateur anonyme", async () => {
    const file = new File([pdfBytes], "registre.pdf", { type: "application/pdf" });
    const arrayBuffer = vi.spyOn(file, "arrayBuffer");
    mocks.getUser.mockResolvedValue({ data: { user: null }, error: null });
    await expect(uploadClientComplianceDocument(documentIdle, documentForm(file)))
      .resolves.toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(mocks.getUser).toHaveBeenCalledOnce();
    expect(arrayBuffer).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.storageFrom).not.toHaveBeenCalled();
  });

  it("valide la réponse bornée avant toute lecture Auth", async () => {
    await expect(respondClientComplianceQuestion(questionIdle, responseForm({ responseText: "x" })))
      .resolves.toEqual({ status: "error", reason: "VALIDATION" });
    expect(mocks.getUser).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("envoie une réponse versionnée et idempotente via le RPC 030", async () => {
    mocks.rpc.mockResolvedValue({ data: { outcome: "COMPLIANCE_RESPONSE_RECEIVED", question_id: questionId, version: 3 }, error: null });
    await expect(respondClientComplianceQuestion(questionIdle, responseForm())).resolves.toEqual({ status: "success", version: 3 });
    expect(mocks.rpc).toHaveBeenCalledWith("respond_client_compliance_question", {
      p_question_id: questionId,
      p_response_text: "Voici la correction administrative demandée.",
      p_idempotency_key: idempotencyKey,
      p_correlation_id: "99999999-9999-4999-8999-999999999999",
    });
    expect(mocks.revalidatePath).toHaveBeenCalledWith("/ar/client/onboarding");
  });

  it("neutralise le diagnostic RPC d’une réponse refusée", async () => {
    mocks.rpc.mockResolvedValue({ data: null, error: { message: "QUESTION_NOT_FOUND tenant-secret" } });
    const result = await respondClientComplianceQuestion(questionIdle, responseForm());
    expect(result).toEqual({ status: "error", reason: "UNAVAILABLE" });
    expect(JSON.stringify(result)).not.toContain("tenant-secret");
  });
});

describe("listClientOnboarding", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getUser.mockResolvedValue({ data: { user: { id: userId } }, error: null });
  });

  it("arrête les lectures tenant sans identité vérifiée", async () => {
    mocks.getUser.mockResolvedValue({ data: { user: null }, error: null });
    await expect(listClientOnboarding()).resolves.toEqual({ status: "error", reason: "UNAUTHENTICATED" });
    expect(mocks.from).not.toHaveBeenCalled();
  });

  it("retourne un état vide sans rôle Client Owner/Admin", async () => {
    mocks.from.mockReturnValue({ select: () => query({ data: [], error: null }) });
    await expect(listClientOnboarding()).resolves.toEqual({ status: "success", organizations: [] });
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("compose le profil, les preuves sans métadonnées Storage et le trial effectif", async () => {
    const results: Record<string, { data: unknown; error: unknown }> = {
      organization_memberships: { data: [{ id: membershipId, organization_id: organizationId }], error: null },
      organization_member_roles: { data: [{ membership_id: membershipId, role_code: "CLIENT_OWNER", revoked_at: null }], error: null },
      organizations: { data: [{ id: organizationId, legal_name: "Atlas Conseil SARL", display_name: "Atlas Conseil", status: "ACTIVE" }], error: null },
      organization_identifiers: { data: [{ organization_id: organizationId, identifier_type: "ICE", normalized_value: "001122334455", verification_status: "VERIFIED" }], error: null },
      client_compliance_cases: { data: [{ id: caseId, organization_id: organizationId, status: "VERIFIED", current_profile_version: 1, submitted_at: "2026-09-11T09:00:00Z", decision_reason_public: null, verified_at: "2026-09-11T10:00:00Z", activated_at: "2026-09-11T10:00:00Z", updated_at: "2026-09-11T10:00:00Z" }], error: null },
      client_profile_versions: { data: [{ compliance_case_id: caseId, organization_id: organizationId, version: 1, created_at: "2026-09-11T08:00:00Z", profile_data: {
        legal_form: "SARL", incorporation_date: "2020-02-20", activity: "Conseil", sector: "Services", employee_count: 12,
        registered_city: "Casablanca", registered_address: { line1: "10 rue Exemple", country_code: "MA" },
        contact: { phone: "+212522000001", email: "contact@example.invalid" },
        representative: { first_name: "Amal", last_name: "Alami", title: "Gérante", email: "amal@example.invalid", phone: "+212600000001", power: "Statuts" },
        declarations: { accuracy_confirmed: true, representation_authorized: true }, if_number: "IFA001", rc_number: "RCA001",
      } }], error: null },
      client_compliance_evidence: { data: [{ compliance_case_id: caseId, organization_id: organizationId, evidence_type: "REGISTRATION_DOCUMENT", review_status: "VERIFIED", object_path: "private/secret.pdf", file_sha256: "secret-hash" }], error: null },
      client_compliance_documents: { data: [{ organization_id: organizationId, document_type: "REGISTRATION_DOCUMENT", version: 2, document_number: "RC-2026-01", issuer: "Tribunal", issued_on: "2026-09-01", expires_on: null, original_file_name: "registre.pdf", status: "PENDING_REVIEW", rejection_reason_public: null, uploaded_at: "2026-09-11T09:00:00Z", storage_object_path: "private/document.pdf", declared_sha256: "private-document-hash" }], error: null },
      client_administrative_anomalies: { data: [{ organization_id: organizationId, client_message_fr: "Le registre doit être corrigé.", client_message_ar: "يجب تصحيح السجل.", severity: "CRITICAL", blocking: true, status: "QUESTIONED", created_at: "2026-09-11T09:30:00Z", entered_value_digest: "sensitive-digest" }], error: null },
      client_compliance_questions: { data: [{ id: questionId, organization_id: organizationId, question_text_fr: "Merci de préciser le numéro du registre.", question_text_ar: "يرجى توضيح رقم السجل.", expected_document_type: "REGISTRATION_DOCUMENT", due_at: "2026-09-20T10:00:00Z", status: "ANSWERED", created_at: "2026-09-11T10:00:00Z", created_by: "internal-user" }], error: null },
      client_compliance_response_versions: { data: [{ question_id: questionId, organization_id: organizationId, version: 2, submitted_at: "2026-09-12T10:00:00Z", response_text: "private response", submitted_by: userId }], error: null },
    };
    mocks.from.mockImplementation((table: string) => ({ select: () => query(results[table] ?? { data: [], error: null }) }));
    mocks.rpc.mockResolvedValue({ data: [{ id: trialId, organization_id: organizationId, compliance_case_id: caseId, effective_status: "TRIAL_ACTIVE", trial_started_at: "2026-09-11T10:00:00Z", trial_ends_at: "2026-10-11T10:00:00Z" }], error: null });

    const result = await listClientOnboarding();
    expect(result.status).toBe("success");
    if (result.status !== "success") throw new Error("unexpected result");
    expect(result.organizations[0]).toMatchObject({
      id: organizationId,
      legalName: "Atlas Conseil SARL",
      ice: "001122334455",
      complianceCase: { status: "VERIFIED", currentProfileVersion: 1 },
      latestProfile: { version: 1 },
      trial: { status: "TRIAL_ACTIVE" },
    });
    expect(result.organizations[0]?.evidence).toEqual([{ type: "REGISTRATION_DOCUMENT", status: "VERIFIED" }]);
    expect(result.organizations[0]?.documents).toEqual([expect.objectContaining({ type: "REGISTRATION_DOCUMENT", version: 2, status: "PENDING_REVIEW" })]);
    expect(result.organizations[0]?.anomalies).toEqual([{ message: "Le registre doit être corrigé.", severity: "CRITICAL", blocking: true, status: "QUESTIONED", createdAt: "2026-09-11T09:30:00Z" }]);
    expect(result.organizations[0]?.questions).toEqual([expect.objectContaining({ id: questionId, text: "Merci de préciser le numéro du registre.", latestResponseVersion: 2 })]);
    expect(JSON.stringify(result)).not.toContain("private/secret.pdf");
    expect(JSON.stringify(result)).not.toContain("secret-hash");
    expect(JSON.stringify(result)).not.toContain("private-document");
    expect(JSON.stringify(result)).not.toContain("sensitive-digest");
    expect(JSON.stringify(result)).not.toContain("private response");
    expect(JSON.stringify(result)).not.toContain("internal-user");
    expect(mocks.rpc).toHaveBeenCalledWith("list_my_client_trials");
  });

  it("rejette une réponse DB non conforme plutôt que de la propager", async () => {
    mocks.from.mockImplementation((table: string) => ({ select: () => query({
      data: table === "organization_memberships" ? [{ id: "invalid", organization_id: organizationId }] : [], error: null,
    }) }));
    await expect(listClientOnboarding()).resolves.toEqual({ status: "error", reason: "UNAVAILABLE" });
  });
});

describe("localisation onboarding", () => {
  it("fournit les mêmes états métier en français et en arabe sans texte vide", () => {
    const fr = getClientOnboardingMessages("fr");
    const ar = getClientOnboardingMessages("ar");
    expect(Object.keys(ar.statuses)).toEqual(Object.keys(fr.statuses));
    expect(Object.values(fr.statuses).every(Boolean)).toBe(true);
    expect(Object.values(ar.statuses).every(Boolean)).toBe(true);
    expect(ar.title).not.toBe(fr.title);
    expect(ar.noCard).toContain("دفع");
  });
});
