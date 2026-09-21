import type { UserActionItem } from "@/modules/shared/lib/action-center/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { clientJourneySteps } from "./view-model";
import type { ClientHomeSnapshot } from "./repository";

export function isDemoClientHomeEnabled() {
  return process.env.MATRICIA_DEMO_ACCESS_ENABLED === "true" && process.env.APP_ENV !== "production";
}

export function isDemoClientOrganization(name: string | null) {
  return Boolean(name && (/^Client · /u.test(name) || /^Client Démo/u.test(name)));
}

function item(partial: UserActionItem): UserActionItem {
  return partial;
}

export function demoClientActions(input: {
  locale: Locale;
  organizationId: string;
  organizationName: string;
  requestId: string | null;
  selectedQuery: string;
  now: string;
}): UserActionItem[] {
  const q = input.selectedQuery;
  const requestHref = input.requestId ? `/${input.locale}/client/demandes/${input.requestId}${q}` : `/${input.locale}/client/demandes${q}`;
  const day = (offset: number) => new Date(Date.parse(input.now) + offset * 86_400_000).toISOString();
  const org = input.organizationName;
  const fr = input.locale === "fr";
  return [
    item({
      id: `demo:${input.organizationId}:diagnostic`,
      kind: "WORK_ITEM",
      title: fr ? "Reprendre un bilan" : "استئناف تحليل",
      detail: fr ? "Diagnostic d’entreprise à finaliser" : "تشخيص المؤسسة بانتظار الإتمام",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "MEDIUM",
      mandatory: false,
      href: `/${input.locale}/client/diagnostics${q}`,
      occurredAt: input.now,
      dueAt: day(7),
      requiresHumanReview: false,
    }),
    item({
      id: `demo:${input.organizationId}:quotes`,
      kind: "WORK_ITEM",
      title: fr ? "Comparer les offres reçues" : "مقارنة العروض المستلمة",
      detail: fr ? "Déploiement de la marque" : "إطلاق العلامة",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "HIGH",
      mandatory: true,
      href: requestHref,
      occurredAt: input.now,
      dueAt: day(3),
      requiresHumanReview: true,
    }),
    item({
      id: `demo:${input.organizationId}:deliverable`,
      kind: "WORK_ITEM",
      title: fr ? "Examiner un livrable — Identité de marque" : "مراجعة تسليم — هوية العلامة",
      detail: fr ? "Charte graphique v2" : "الميثاق البصري v2",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "HIGH",
      mandatory: true,
      href: `/${input.locale}/client/missions${q}`,
      occurredAt: input.now,
      dueAt: day(5),
      requiresHumanReview: true,
    }),
    item({
      id: `demo:${input.organizationId}:document`,
      kind: "WORK_ITEM",
      title: fr ? "Registre de commerce" : "السجل التجاري",
      detail: fr ? "Document à relire" : "مستند للمراجعة",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "MEDIUM",
      mandatory: false,
      href: `/${input.locale}/client/documents${q}`,
      occurredAt: input.now,
      dueAt: day(2),
      requiresHumanReview: false,
    }),
    item({
      id: `demo:${input.organizationId}:doc-2`,
      kind: "WORK_ITEM",
      title: fr ? "Attestation fiscale" : "شهادة جبائية",
      detail: fr ? "Document à relire" : "مستند للمراجعة",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "MEDIUM",
      mandatory: false,
      href: `/${input.locale}/client/documents${q}`,
      occurredAt: input.now,
      dueAt: null,
      requiresHumanReview: false,
    }),
    item({
      id: `demo:${input.organizationId}:doc-3`,
      kind: "WORK_ITEM",
      title: fr ? "Statuts" : "النظام الأساسي",
      detail: fr ? "Document à relire" : "مستند للمراجعة",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "LOW",
      mandatory: false,
      href: `/${input.locale}/client/documents${q}`,
      occurredAt: input.now,
      dueAt: null,
      requiresHumanReview: false,
    }),
    item({
      id: `demo:${input.organizationId}:message-1`,
      kind: "MESSAGE",
      title: fr ? "Répondre à une question" : "الرد على سؤال",
      detail: fr ? "Agence B · Déploiement de la marque" : "الوكالة ب · إطلاق العلامة",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "MEDIUM",
      mandatory: false,
      href: `/${input.locale}/messagerie${q}`,
      occurredAt: input.now,
      dueAt: null,
      requiresHumanReview: false,
    }),
    item({
      id: `demo:${input.organizationId}:message-2`,
      kind: "MESSAGE",
      title: fr ? "Nouveau message — planning de lancement" : "رسالة جديدة — جدول الإطلاق",
      detail: fr ? "2 messages à traiter" : "رسالتان للمعالجة",
      organizationName: org,
      organizationId: input.organizationId,
      priority: "MEDIUM",
      mandatory: false,
      href: `/${input.locale}/messagerie${q}`,
      occurredAt: input.now,
      dueAt: null,
      requiresHumanReview: false,
    }),
  ];
}

export function applyDemoClientHome(input: {
  locale: Locale;
  organizationId: string | null;
  organizationName: string | null;
  selectedQuery: string;
  now: string;
  items: readonly UserActionItem[];
  snapshot: ClientHomeSnapshot;
}): { items: UserActionItem[]; snapshot: ClientHomeSnapshot } {
  if (!isDemoClientHomeEnabled() || !input.organizationId || !isDemoClientOrganization(input.organizationName)) {
    return { items: [...input.items], snapshot: input.snapshot };
  }
  const extras = demoClientActions({
    locale: input.locale,
    organizationId: input.organizationId,
    organizationName: input.organizationName ?? "Client",
    requestId: input.snapshot.status === "success" ? input.snapshot.lastRequestId : null,
    selectedQuery: input.selectedQuery,
    now: input.now,
  });
  const items = [...extras, ...input.items.filter((item) => !extras.some((demo) => demo.href === item.href && demo.kind === item.kind))];
  if (input.snapshot.status !== "success") return { items, snapshot: input.snapshot };

  const requestId = input.snapshot.lastRequestId ?? input.snapshot.featuredProject?.requestId ?? "demo-request";
  const href = `/${input.locale}/client/demandes/${requestId}`;
  const featured = input.snapshot.featuredProject
    ? {
        ...input.snapshot.featuredProject,
        title: input.locale === "ar" ? "إطلاق العلامة" : "Déploiement de la marque",
        status: "DRAFT",
        steps: clientJourneySteps("DRAFT"),
      }
    : {
        requestId,
        title: input.locale === "ar" ? "إطلاق العلامة" : "Déploiement de la marque",
        status: "DRAFT",
        createdAt: input.now,
        quoteCount: 2,
        href,
        steps: clientJourneySteps("DRAFT"),
      };
  const comparison = input.snapshot.comparison ?? {
    requestId,
    href,
    description: input.locale === "ar" ? "استراتيجية، هوية ودعم الإطلاق" : "Stratégie, identité et support de lancement",
    columns: [
      { quoteId: `${requestId}-a`, label: input.locale === "ar" ? "العرض أ" : "Offre A", durationDays: 42, deliverablesCount: 3, totalMinor: "4500000", currency: "MAD", priceRank: 1, exclusions: input.locale === "ar" ? "خارج الطباعة الصناعية" : "Hors production print" },
      { quoteId: `${requestId}-b`, label: input.locale === "ar" ? "العرض ب" : "Offre B", durationDays: 56, deliverablesCount: 2, totalMinor: "3800000", currency: "MAD", priceRank: 2, exclusions: input.locale === "ar" ? "خارج السفر الدولي" : "Hors déplacements internationaux" },
    ],
  };

  return {
    items,
    snapshot: {
      ...input.snapshot,
      featuredProject: featured,
      comparison,
      insights: {
        documentsToReview: items.filter((item) => /document|pièce|مستند/i.test(`${item.title} ${item.detail} ${item.href}`)).length,
        nextMilestoneTitle: input.snapshot.insights.nextMilestoneTitle ?? (input.locale === "ar" ? "اختيار مزوّد" : "Choisir un prestataire"),
        nextMilestoneDue: input.snapshot.insights.nextMilestoneDue ?? new Date(Date.parse(input.now) + 6 * 86_400_000).toISOString(),
        messagesToHandle: items.filter((item) => item.kind === "MESSAGE").length,
      },
    },
  };
}
