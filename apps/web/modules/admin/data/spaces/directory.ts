import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { adminActorLinks, adminParcoursLinks } from "./admin-nav";

export function adminDirectoryGroups(locale: Locale, q: string) {
  const p = `/${locale}`;
  const fr = locale === "fr";
  return [
    {
      id: "actors",
      title: fr ? "Acteurs & accès" : "الفاعلون والوصول",
      tone: "violet" as const,
      links: adminActorLinks(locale, q).map(({ href, label }) => ({ href, label })),
    },
    {
      id: "parcours",
      title: fr ? "Parcours & dossiers" : "المسارات والملفات",
      tone: "peach" as const,
      links: adminParcoursLinks(locale, q).map(({ href, label }) => ({ href, label })),
    },
    {
      id: "catalog",
      title: fr ? "Catalogue & moteurs" : "الدليل والمحركات",
      tone: "mint" as const,
      links: [
        { href: `${p}/administration/catalogue${q}#domaines`, label: fr ? "Domaines, catégories & services" : "المجالات والفئات والخدمات" },
        { href: `${p}/administration/catalogue${q}#questions`, label: fr ? "Questions" : "الأسئلة" },
        { href: `${p}/administration/catalogue${q}#questionnaires`, label: fr ? "Questionnaires" : "الاستبيانات" },
        { href: `${p}/administration/catalogue/validation${q}#regles`, label: fr ? "Règles conditionnelles" : "قواعد شرطية" },
        { href: `${p}/administration/catalogue/validation${q}#simulation`, label: fr ? "Simulations sandbox" : "محاكاة الصندوق الرملي" },
        { href: `${p}/administration/catalogue/publications${q}`, label: fr ? "Publications & versions" : "المنشورات والنسخ" },
        { href: `${p}/administration/clonage${q}`, label: fr ? "Clonage & provenance" : "الاستنساخ والمصدر" },
        { href: `${p}/administration/catalogue/validation${q}#revue`, label: fr ? "Suggestions IA & revue humaine" : "اقتراحات الذكاء ومراجعة بشرية" },
        { href: `${p}/administration/fiscalite-maroc${q}`, label: fr ? "Fiscalité Maroc" : "الضرائب المغربية" },
        { href: `${p}/administration/questionnaires/analytique${q}`, label: fr ? "Benchmarks anonymisés" : "مراجع مجهولة" },
      ],
    },
    {
      id: "finance",
      title: fr ? "Finance & monétisation" : "المالية والتسييل",
      tone: "peach" as const,
      links: [
        { href: `${p}/administration/finance${q}#plans`, label: fr ? "Plans & abonnements" : "الخطط والاشتراكات" },
        { href: `${p}/administration/finance${q}#boxes`, label: fr ? "Boxes" : "الصناديق" },
        { href: `${p}/administration/finance${q}#credits`, label: fr ? "Crédits & ledger" : "الأرصدة والدفتر" },
        { href: `${p}/administration/finance${q}#paiements`, label: fr ? "Paiements" : "المدفوعات" },
        { href: `${p}/administration/finance${q}#factures-clients`, label: fr ? "Factures clients" : "فواتير العملاء" },
        { href: `${p}/administration/providers${q}`, label: fr ? "Factures prestataires" : "فواتير مقدمي الخدمات" },
        { href: `${p}/administration/finance${q}#rapprochements`, label: fr ? "Rapprochements" : "المطابقات" },
        { href: `${p}/administration/approbations-finance${q}#commissions`, label: fr ? "Commissions" : "العمولات" },
        { href: `${p}/administration/finance${q}#centres-couts`, label: fr ? "Centres de coûts" : "مراكز التكلفة" },
        { href: `${p}/administration/finance${q}#pnl`, label: fr ? "P&L bibliothèques" : "أرباح المكتبات" },
        { href: `${p}/administration/finance${q}#cloture`, label: fr ? "Clôture fournisseurs" : "إغلاق الموردين" },
        { href: `${p}/administration/achats-groupes${q}`, label: fr ? "Achats groupés" : "مشتريات مجمّعة" },
        { href: `${p}/administration/incitations${q}`, label: fr ? "ROI & économies" : "العائد والوفورات" },
        { href: `${p}/administration/approbations-finance${q}`, label: fr ? "Approbations finance" : "مصادقات المالية" },
      ],
    },
    {
      id: "growth",
      title: fr ? "Pilotage & croissance" : "القيادة والنمو",
      tone: "sky" as const,
      links: [
        { href: `${p}/administration/command-center${q}#command-today`, label: fr ? "Centre de commandement" : "مركز القيادة" },
        { href: `${p}/administration/marketing-autopilot${q}#gouvernance`, label: fr ? "Marketing Autopilot" : "التسويق الآلي" },
        { href: `${p}/administration/marketing-autopilot${q}#calendrier`, label: fr ? "Calendrier éditorial" : "التقويم التحريري" },
        { href: `${p}/administration/marketing-autopilot${q}#connexions`, label: fr ? "Connexions sociales" : "الارتباطات الاجتماعية" },
        { href: `${p}/administration/catalogue/publications${q}`, label: fr ? "Publications & validation" : "المنشورات والمصادقة" },
        { href: `${p}/administration/marketing-autopilot${q}#attribution`, label: fr ? "Attribution CTA" : "إسناد الدعوة" },
        { href: `${p}/administration/questionnaires/analytique${q}`, label: fr ? "Analytics & rapports" : "تحليلات وتقارير" },
        { href: `${p}/franchise/relances${q}`, label: fr ? "Relances & digest franchise" : "متابعات وملخص الامتياز" },
        { href: `${p}/administration/incitations${q}`, label: fr ? "Incitations & récompenses" : "الحوافز والمكافآت" },
      ],
    },
    {
      id: "ops",
      title: fr ? "Opérations, sécurité & configuration" : "التشغيل والأمن والإعداد",
      tone: "mint" as const,
      links: [
        { href: `${p}/administration/operations${q}#operations-summary`, label: fr ? "Opérations & files de traitement" : "التشغيل وطوابير المعالجة" },
        { href: `${p}/administration/operations${q}#outbox`, label: fr ? "Event Outbox & workers" : "صندوق الأحداث والعاملون" },
        { href: `${p}/administration/operations${q}#webhooks`, label: fr ? "Webhooks & intégrations" : "الويب هوك والتكاملات" },
        { href: `${p}/administration/anti-abus${q}`, label: fr ? "Anti-abus" : "مكافحة الإساءة" },
        { href: `${p}/administration/operations${q}#latest-audit-events`, label: fr ? "Audit & traçabilité" : "التدقيق والتتبع" },
        { href: `${p}/securite/sessions${q}`, label: fr ? "Sessions & sécurité" : "الجلسات والأمن" },
        { href: `${p}/administration/anti-abus${q}#rls`, label: fr ? "RLS & contrôle des accès" : "الصفوف والتحكم في الوصول" },
        { href: `${p}/administration/operations${q}#stockage`, label: fr ? "Stockage & antivirus" : "التخزين ومضاد الفيروسات" },
        { href: `${p}/administration/operations${q}#sante`, label: fr ? "Santé des services" : "صحة الخدمات" },
        { href: `${p}/administration/operations${q}#parametres`, label: fr ? "Paramètres plateforme" : "إعدادات المنصة" },
        { href: `${p}/administration/operations${q}#archives`, label: fr ? "Archives & restauration" : "الأرشيف والاستعادة" },
      ],
    },
  ];
}

export function inferOrgType(name: string, locale: Locale) {
  if (/franchis/i.test(name)) return locale === "ar" ? "امتياز" : "Franchisé";
  if (/presta|provider|sous-trait/i.test(name)) return locale === "ar" ? "مقدّم خدمات" : "Prestataire";
  if (/admin/i.test(name)) return locale === "ar" ? "إدارة" : "Interne";
  return locale === "ar" ? "عميل" : "Client";
}
