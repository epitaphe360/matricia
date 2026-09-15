import type { Locale } from "@/lib/i18n/locale";

export type ModuleSpace = "client" | "provider" | "franchise" | "admin" | "shared";

const CLIENT_ALL = ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_ACCOUNTING", "CLIENT_MEMBER", "CLIENT_VIEWER"] as const;
const PROVIDER_ALL = ["PROVIDER_OWNER", "PROVIDER_MANAGER", "PROVIDER_SALES", "PROVIDER_TECHNICIAN", "PROVIDER_VIEWER"] as const;
const FRANCHISE_ALL = ["FRANCHISE_OWNER", "FRANCHISE_MANAGER", "FRANCHISE_EXPERT", "FRANCHISE_PROVIDER_MANAGER", "FRANCHISE_ACCOUNTING", "FRANCHISE_VIEWER"] as const;
const ADMIN_ALL = ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "COMPLIANCE_MANAGER", "LIBRARY_MANAGER", "DISPUTE_MANAGER", "READ_ONLY_AUDITOR"] as const;

type ModuleRouteDefinition = { id: string; path: string; space: ModuleSpace; roles?: readonly string[]; platformRoles?: readonly string[]; requiresMembership?: boolean; authenticated?: boolean };

/** Registre unique de navigation. Il améliore la découvrabilité; les pages gardent leurs contrôles serveur et RLS. */
export const MODULE_ROUTE_REGISTRY = [
  { id: "client-home", path: "client/diagnostics", space: "client", roles: CLIENT_ALL },
  { id: "client-onboarding", path: "client/onboarding", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN"] },
  { id: "client-questionnaires", path: "client/questionnaires", space: "client", roles: CLIENT_ALL },
  { id: "client-requests", path: "client/demandes", space: "client", roles: CLIENT_ALL },
  { id: "client-missions", path: "client/missions", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_VIEWER"] },
  { id: "client-portfolio", path: "client/portefeuille", space: "client", roles: CLIENT_ALL },
  { id: "client-documents", path: "client/documents", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN"] },
  { id: "client-disputes", path: "client/litiges", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN"] },
  { id: "client-subscription", path: "client/abonnement", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_ACCOUNTING", "CLIENT_VIEWER"] },
  { id: "client-credits", path: "client/credits", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_ACCOUNTING"] },
  { id: "client-volume", path: "client/achats-groupes", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER"] },
  { id: "client-rewards", path: "client/recompenses", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_ACCOUNTING"] },
  { id: "client-favorites", path: "client/favoris", space: "client", roles: ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER", "CLIENT_VIEWER"] },
  { id: "provider-qualification", path: "sous-traitant/qualification", space: "provider", roles: PROVIDER_ALL },
  { id: "provider-quotes", path: "sous-traitant/devis", space: "provider", roles: PROVIDER_ALL },
  { id: "provider-missions", path: "sous-traitant/missions", space: "provider", roles: PROVIDER_ALL },
  { id: "provider-billing", path: "sous-traitant/facturation", space: "provider", roles: ["PROVIDER_OWNER", "PROVIDER_MANAGER", "PROVIDER_SALES", "PROVIDER_VIEWER"] },
  { id: "provider-reputation", path: "sous-traitant/reputation", space: "provider", roles: PROVIDER_ALL },
  { id: "franchise-governance", path: "franchise/gouvernance", space: "franchise", roles: FRANCHISE_ALL, platformRoles: ADMIN_ALL },
  { id: "franchise-performance", path: "franchise/performance", space: "franchise", roles: FRANCHISE_ALL, platformRoles: ADMIN_ALL },
  { id: "franchise-followups", path: "franchise/relances", space: "franchise", roles: FRANCHISE_ALL, platformRoles: ADMIN_ALL },
  { id: "franchise-digest", path: "franchise/digest", space: "franchise", roles: FRANCHISE_ALL, platformRoles: ADMIN_ALL },
  { id: "admin-command", path: "administration/command-center", space: "admin", platformRoles: ADMIN_ALL },
  { id: "admin-clients", path: "administration/clients", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-client-compliance", path: "administration/conformite-clients", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-providers", path: "administration/providers", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "FINANCE_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-finance", path: "administration/finance", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-finance-approvals", path: "administration/approbations-finance", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-tax", path: "administration/fiscalite-maroc", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-volume", path: "administration/achats-groupes", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER"] },
  { id: "admin-franchise", path: "administration/gouvernance-franchise", space: "admin", platformRoles: ADMIN_ALL },
  { id: "admin-incentives", path: "administration/incitations", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "FINANCE_MANAGER", "COMPLIANCE_MANAGER"] },
  { id: "admin-catalogue", path: "administration/catalogue", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-catalogue-validation", path: "administration/catalogue/validation", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-catalogue-publications", path: "administration/catalogue/publications", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-cloning", path: "administration/clonage", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-questionnaires", path: "administration/questionnaires/analytique", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"] },
  { id: "admin-marketing", path: "administration/marketing-autopilot", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "READ_ONLY_AUDITOR"] },
  { id: "admin-operations", path: "administration/operations", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "READ_ONLY_AUDITOR"] },
  { id: "admin-abuse", path: "administration/anti-abus", space: "admin", platformRoles: ["SUPER_ADMIN", "MATRICIA_ADMIN", "READ_ONLY_AUDITOR"] },
  { id: "admin-procurement", path: "administration/v4-1/procurement", space: "admin", platformRoles: ADMIN_ALL },
  { id: "shared-actions", path: "actions", space: "shared", requiresMembership: true },
  { id: "shared-messages", path: "messagerie", space: "shared", requiresMembership: true },
  { id: "shared-notifications", path: "notifications", space: "shared", requiresMembership: true },
  { id: "shared-organization", path: "organisation", space: "shared", authenticated: true },
  { id: "shared-roles", path: "organisation/roles", space: "shared", requiresMembership: true },
  { id: "shared-account", path: "securite/compte", space: "shared", authenticated: true },
  { id: "shared-sessions", path: "securite/sessions", space: "shared", authenticated: true },
] as const satisfies readonly ModuleRouteDefinition[];

export type ModuleRoute = (typeof MODULE_ROUTE_REGISTRY)[number];
export type ModuleRouteId = ModuleRoute["id"];

type VisibilityContext = { membershipCount: number; membershipRoles: ReadonlySet<string>; platformRoles: ReadonlySet<string> };

export type AuthorizedOrganizationMembership = { membershipId: string; organizationId: string };

export function resolveOrganizationContext(memberships: readonly AuthorizedOrganizationMembership[], requestedOrganizationId: string | null) {
  const requested = requestedOrganizationId ? memberships.find((membership) => membership.organizationId === requestedOrganizationId) : undefined;
  return { selected: requested ?? memberships[0] ?? null, rejected: requestedOrganizationId !== null && !requested } as const;
}

export function visibleModuleRoutes(context: VisibilityContext): readonly ModuleRoute[] {
  return MODULE_ROUTE_REGISTRY.filter((candidate) => {
    const route: ModuleRouteDefinition = candidate;
    return route.authenticated === true || (route.requiresMembership === true && context.membershipCount > 0) || route.roles?.some((role) => context.membershipRoles.has(role)) === true || route.platformRoles?.some((role) => context.platformRoles.has(role)) === true;
  });
}

const frLabels: Record<ModuleRouteId, string> = {
  "client-home": "Bilans et priorités", "client-onboarding": "Dossier de l’entreprise", "client-questionnaires": "Questionnaires", "client-requests": "Demandes et devis", "client-missions": "Contrats, missions et livrables", "client-portfolio": "Portefeuille, projets et budgets", "client-documents": "Documents et renouvellements", "client-disputes": "Litiges et preuves", "client-subscription": "Abonnement", "client-credits": "Crédits commerciaux", "client-volume": "Achats groupés", "client-rewards": "Récompenses, parrainage et retour sur investissement", "client-favorites": "Sous-traitants favoris",
  "provider-qualification": "Qualification et compétences", "provider-quotes": "Consultations et devis", "provider-missions": "Missions, avenants et livraisons", "provider-billing": "Facturation et rapprochements", "provider-reputation": "Réputation, badges et capacité",
  "franchise-governance": "Gouvernance et mandats", "franchise-performance": "Performance", "franchise-followups": "Relances", "franchise-digest": "Résumé quotidien",
  "admin-command": "Centre de pilotage", "admin-clients": "Entreprises clientes", "admin-client-compliance": "Conformité des clients", "admin-providers": "Sous-traitants", "admin-finance": "Paiements et abonnements", "admin-finance-approvals": "Approbations et commissions", "admin-tax": "Fiscalité Maroc", "admin-volume": "Achats groupés", "admin-franchise": "Gouvernance des franchises", "admin-incentives": "Récompenses et parrainage", "admin-catalogue": "Référentiel interne", "admin-catalogue-validation": "Validation du référentiel", "admin-catalogue-publications": "Publications du référentiel", "admin-cloning": "Clonage avec provenance", "admin-questionnaires": "Analytique des questionnaires", "admin-marketing": "Marketing et calendrier éditorial", "admin-operations": "Exploitation et traitements", "admin-abuse": "Contrôle des abus", "admin-procurement": "Achats et fournisseurs avancés",
  "shared-actions": "Actions requises", "shared-messages": "Messagerie sécurisée", "shared-notifications": "Notifications", "shared-organization": "Organisation et espace de travail", "shared-roles": "Rôles et invitations", "shared-account": "Sécurité du compte", "shared-sessions": "Sessions actives",
};

const arLabels: Record<ModuleRouteId, string> = {
  "client-home": "التحليلات والأولويات", "client-onboarding": "ملف المؤسسة", "client-questionnaires": "الاستبيانات", "client-requests": "الطلبات والعروض", "client-missions": "العقود والمهام والتسليمات", "client-portfolio": "المحفظة والمشاريع والميزانيات", "client-documents": "المستندات والتجديدات", "client-disputes": "النزاعات والأدلة", "client-subscription": "الاشتراك", "client-credits": "الأرصدة التجارية", "client-volume": "المشتريات المجمعة", "client-rewards": "المكافآت والإحالة والعائد على الاستثمار", "client-favorites": "مقدمو الخدمات المفضلون",
  "provider-qualification": "التأهيل والكفاءات", "provider-quotes": "الاستشارات والعروض", "provider-missions": "المهام والملاحق والتسليمات", "provider-billing": "الفوترة والمطابقة", "provider-reputation": "السمعة والشارات والقدرة",
  "franchise-governance": "الحوكمة والتفويضات", "franchise-performance": "الأداء", "franchise-followups": "المتابعات", "franchise-digest": "الملخص اليومي",
  "admin-command": "مركز القيادة", "admin-clients": "المؤسسات العميلة", "admin-client-compliance": "امتثال العملاء", "admin-providers": "مقدمو الخدمات", "admin-finance": "المدفوعات والاشتراكات", "admin-finance-approvals": "الموافقات والعمولات", "admin-tax": "الضرائب المغربية", "admin-volume": "المشتريات المجمعة", "admin-franchise": "حوكمة الامتيازات", "admin-incentives": "المكافآت والإحالة", "admin-catalogue": "المرجع الداخلي", "admin-catalogue-validation": "اعتماد المرجع", "admin-catalogue-publications": "إصدارات المرجع", "admin-cloning": "الاستنساخ مع توثيق المصدر", "admin-questionnaires": "تحليلات الاستبيانات", "admin-marketing": "التسويق والتقويم التحريري", "admin-operations": "التشغيل والمعالجات", "admin-abuse": "مراقبة إساءة الاستخدام", "admin-procurement": "المشتريات والموردون المتقدمون",
  "shared-actions": "الإجراءات المطلوبة", "shared-messages": "المراسلة الآمنة", "shared-notifications": "الإشعارات", "shared-organization": "المؤسسة ومساحة العمل", "shared-roles": "الأدوار والدعوات", "shared-account": "أمان الحساب", "shared-sessions": "الجلسات النشطة",
};

export const moduleHubCopy = {
  fr: { title: "Vos espaces de travail", description: "Les espaces Client, Sous-traitant et Franchise utilisent uniquement les rôles de l’entreprise sélectionnée. L’administration plateforme reste séparée.", unavailable: "Impossible de charger vos espaces pour le moment. Réessayez sans changer d’organisation.", empty: "Aucun espace métier n’est encore associé à ce compte.", spaces: { client: "Client — entreprise sélectionnée", provider: "Sous-traitant — entreprise sélectionnée", franchise: "Franchise — entreprise sélectionnée", admin: "Administration plateforme", shared: "Compte et collaboration" }, links: frLabels },
  ar: { title: "مساحات عملك", description: "تستخدم مساحات العميل ومقدم الخدمات والامتياز أدوار المؤسسة المختارة فقط. تبقى إدارة المنصة منفصلة.", unavailable: "تعذر تحميل مساحاتك حالياً. حاول مجدداً دون تغيير المؤسسة.", empty: "لا توجد مساحة مهنية مرتبطة بهذا الحساب بعد.", spaces: { client: "العميل — المؤسسة المختارة", provider: "مقدم الخدمات — المؤسسة المختارة", franchise: "الامتياز — المؤسسة المختارة", admin: "إدارة المنصة", shared: "الحساب والتعاون" }, links: arLabels },
} as const;

export const dashboardHomeCopy = {
  fr: { eyebrow: "Espace sécurisé", title: "Bonjour, que devez-vous faire maintenant ?", intro: "Retrouvez vos priorités, votre entreprise active et les outils utiles à votre rôle.", actionsTitle: "Priorités de l’entreprise", actionsDescription: "Éléments autorisés associés à l’entreprise sélectionnée. Le centre complet reste accessible séparément.", actionsEmpty: "Aucune action prioritaire associée à cette entreprise.", actionsError: "Les priorités ne peuvent pas être chargées. Vos espaces restent disponibles.", actionsCta: "Voir le centre d’actions", organizationsTitle: "Entreprise active", organizationsDescription: "Choisissez-la par son nom. L’adresse transmise est vérifiée contre vos adhésions actives; chaque destination revalide ensuite vos droits.", contextRejected: "Cette entreprise n’est pas autorisée pour votre compte. Le premier périmètre valide a été sélectionné.", contextLimit: "Cette sélection filtre cet accueil et sa navigation. Les écrans métier restent responsables de leur propre contexte serveur.", organizationError: "Impossible de charger les entreprises autorisées.", organizationEmpty: "Aucune entreprise active n’est encore associée à votre compte.", organizationCta: "Gérer l’organisation", selected: "Entreprise sélectionnée", select: "Travailler pour", accountTitle: "Compte et sécurité", signedInAs: "Session ouverte avec", sessionsCta: "Vérifier mes sessions", signOut: "Se déconnecter", signOutError: "La déconnexion n’a pas abouti. Réessayez.", language: "العربية", priority: { CRITICAL: "Urgent", HIGH: "Prioritaire", MEDIUM: "À prévoir", LOW: "Information" }, status: { ACTIVE: "Active", TRIAL: "Essai", SUSPENDED: "Suspendue", CLOSED: "Fermée", unknown: "Statut à vérifier" } },
  ar: { eyebrow: "مساحة آمنة", title: "مرحباً، ما الذي يجب إنجازه الآن؟", intro: "اعثر على أولوياتك ومؤسستك النشطة والأدوات المناسبة لدورك.", actionsTitle: "أولويات المؤسسة", actionsDescription: "العناصر المصرح بها والمرتبطة بالمؤسسة المختارة. يبقى مركز الإجراءات الكامل متاحاً بشكل منفصل.", actionsEmpty: "لا توجد إجراءات ذات أولوية مرتبطة بهذه المؤسسة.", actionsError: "تعذر تحميل الأولويات. تبقى مساحاتك متاحة.", actionsCta: "عرض مركز الإجراءات", organizationsTitle: "المؤسسة النشطة", organizationsDescription: "اخترها بالاسم. يتم التحقق من العنوان وفق عضوياتك النشطة، ثم تعيد كل وجهة التحقق من صلاحياتك.", contextRejected: "هذه المؤسسة غير مصرح بها لحسابك. تم اختيار أول نطاق صالح.", contextLimit: "تقوم هذه الخانة بتصفية صفحة الاستقبال والتنقل فقط. تبقى الشاشات المهنية مسؤولة عن سياقها الآمن.", organizationError: "تعذر تحميل المؤسسات المصرح بها.", organizationEmpty: "لا توجد مؤسسة نشطة مرتبطة بحسابك بعد.", organizationCta: "إدارة المؤسسة", selected: "المؤسسة المختارة", select: "العمل لصالح", accountTitle: "الحساب والأمان", signedInAs: "الجلسة مفتوحة بواسطة", sessionsCta: "التحقق من جلساتي", signOut: "تسجيل الخروج", signOutError: "تعذر تسجيل الخروج. حاول مجدداً.", language: "Français", priority: { CRITICAL: "عاجل", HIGH: "أولوية", MEDIUM: "للتخطيط", LOW: "معلومة" }, status: { ACTIVE: "نشطة", TRIAL: "تجريبية", SUSPENDED: "موقوفة", CLOSED: "مغلقة", unknown: "الحالة تحتاج إلى تحقق" } },
} as const satisfies Record<Locale, Record<string, unknown>>;
