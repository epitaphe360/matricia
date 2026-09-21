import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import {
  CompanySecurityWorkbench,
  ConsultationDetailWorkbench,
  InvoiceSettlementWorkbench,
  MessagesNotificationsWorkbench,
  MissionDeliveryWorkbench,
  ProviderOutOfScope,
  QuoteMultilineWorkbench,
  QuoteRevisionWorkbench,
} from "./workbenches";

describe("provider nested workbenches 09-15", () => {
  it("compose les écrans de détail sans exemple illustratif ni devis concurrent", () => {
    const html = [
      renderToStaticMarkup(<ConsultationDetailWorkbench locale="fr" query="" consultationId="cr1" />),
      renderToStaticMarkup(<QuoteMultilineWorkbench locale="fr" query="" quoteId="d1" />),
      renderToStaticMarkup(<QuoteRevisionWorkbench locale="fr" query="" quoteId="d2" />),
      renderToStaticMarkup(<MissionDeliveryWorkbench locale="fr" query="" missionId="m1" />),
      renderToStaticMarkup(<InvoiceSettlementWorkbench locale="fr" query="" invoiceId="i1" />),
      renderToStaticMarkup(<MessagesNotificationsWorkbench locale="fr" query="" threadId="cr1" />),
      renderToStaticMarkup(<CompanySecurityWorkbench locale="fr" query="" organizationName="Studio Atlas" userEmail="pro@example.ma" />),
    ].join("\n");
    expect(html).toContain("provider-workbench");
    expect(html).toContain("Adéquation avec votre qualification");
    expect(html).toContain("Créer un devis multiligne");
    expect(html).toContain("Réviser et soumettre le devis");
    expect(html).toContain("Mission et livraison");
    expect(html).toContain("Facture et règlement");
    expect(html).toContain("Messages et notifications");
    expect(html).toContain("Authentification à deux facteurs");
    expect(html).toContain("Aucun devis d’un autre prestataire n’est visible");
    expect(html).toContain("Aucun montant de tiers");
    expect(html).toContain("calculés et sécurisés par le serveur");
    expect(html).toContain("MAD");
    expect(html).toContain("dir=\"ltr\"");
    expect(html).toContain("Montant indisponible");
    expect(html).toContain("Aucune notification pour le moment.");
    expect(html).not.toContain("Windows");
    expect(html).not.toContain("12 000");
    expect(html).not.toMatch(/exemple illustratif/i);
    expect(html).not.toMatch(/TODO:|FIXME:|\bTBD\b/);
    expect(html).not.toMatch(/parseFloat/);
    expect(html).not.toContain("TVA (20 %)");
  });

  it("expose un état FR/AR et un refus de périmètre sans redirection vide", () => {
    const ar = renderToStaticMarkup(<ConsultationDetailWorkbench locale="ar" query="" consultationId="cr1" />);
    const scope = renderToStaticMarkup(<ProviderOutOfScope locale="fr" query="" />);
    expect(ar).toMatch(/[\u0600-\u06ff]/u);
    expect(ar).toContain("لا يظهر أي عرض لمقدم خدمة آخر");
    expect(scope).toContain("n’est pas dans votre périmètre autorisé");
    expect(scope).toContain("Aucun devis concurrent");
  });

  it("affiche les pièces RFQ partagées et refuse les documents de qualification du prestataire", () => {
    const invitation = {
      id: "11111111-1111-4111-8111-111111111111",
      status: "INVITED" as const,
      rowVersion: 1,
      rfqId: "22222222-2222-4222-8222-222222222222",
      deadline: "2027-01-01T12:00:00.000Z",
      requestId: "33333333-3333-4333-8333-333333333333",
      description: "Rénovation lot CVC",
      regionCode: "RABAT",
      currency: "MAD",
      taxCategoryCode: null,
      quote: null,
      pack: {
        objective: "Mettre à niveau le CVC",
        scope: ["Lot CVC"],
        deliverables: ["Devis détaillé"],
        constraints: ["Horaires scolaires"],
        documents: [
          { id: "55555555-5555-4555-8555-555555555555", title: "Cahier des charges", type: "PDF", size: "2,4 Mo" },
          { title: "Note interne sans fichier" },
        ],
      },
    };
    const withPack = renderToStaticMarkup(<ConsultationDetailWorkbench locale="fr" query="" consultationId={invitation.id} invitation={invitation} />);
    expect(withPack).toContain("Cahier des charges");
    expect(withPack).toContain("2,4 Mo");
    expect(withPack).toContain("Mettre à niveau le CVC");
    expect(withPack).toContain(`/api/provider/consultations/${invitation.id}/documents/55555555-5555-4555-8555-555555555555`);
    expect(withPack).toContain(`/sous-traitant/messages?rfq=${invitation.rfqId}`);
    expect(withPack).toContain("client-feed-download");
    expect(withPack).toContain("Télécharger");
    expect(withPack).not.toContain("Extrait d’immatriculation");
    expect(withPack.match(/client-feed-download/g)?.length).toBe(1);
    const empty = renderToStaticMarkup(<ConsultationDetailWorkbench locale="fr" query="" consultationId={invitation.id} invitation={{ ...invitation, pack: { objective: null, scope: [], deliverables: [], constraints: [], documents: [] } }} />);
    expect(empty).toContain("Aucun document n’a encore été partagé");
    expect(empty).not.toContain("Extrait d’immatriculation");
    expect(empty).not.toContain("Attestation fiscale");
  });

  it("affiche une facture réelle sans inventer de montant ni de téléchargement", () => {
    const invoice = {
      id: "66666666-6666-4666-8666-666666666666",
      number: "F-2026-01",
      currency: "MAD",
      totalMinor: "1250",
      paidMinor: "0",
      outstandingMinor: "1250",
      paymentStatus: "OPEN",
      dueOn: "2026-10-01",
    };
    const html = renderToStaticMarkup(<InvoiceSettlementWorkbench locale="fr" query="" invoiceId={invoice.id} invoice={invoice} />);
    expect(html).toContain("F-2026-01");
    expect(html).toContain("12,50");
    expect(html).not.toContain("Montant indisponible");
    expect(html).not.toMatch(/client-feed-download/);
    expect(html).not.toContain("TVA (20 %)");
  });
});
