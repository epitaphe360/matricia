import type { Locale } from "@/lib/i18n/locale";

const fr = {
  title: "Facturation et règlements", description: "Suivez les montants dus, relevés, factures, paiements et rapprochements issus des écritures immuables.",
  back: "Tableau de bord", language: "العربية", payables: "Montants dus", statements: "Relevés", invoices: "Factures et soldes", payments: "Règlements",
  allocations: "Historique des rapprochements", emptyAllocations: "Aucun rapprochement enregistré.", immutableAllocation: "Affectation comptable immuable",
  allocated: "Affecté", unallocated: "Non affecté", reconciliationHint: "Seuls les règlements avec un reliquat et les factures avec un solde sont proposés. Le serveur refuse toute suraffectation.",
  commands: "Opérations autorisées", empty: "Aucune donnée enregistrée.", number: "Numéro", period: "Période", amount: "Montant", status: "Statut", due: "Échéance", paid: "Payé", outstanding: "Solde",
  date: "Date", mission: "Mission", reference: "Référence", currency: "Devise", proof: "Empreinte SHA-256", minor: "Montant en unités mineures", event: "Type d’événement",
  recordPayable: "Enregistrer un montant dû", issueStatement: "Émettre un relevé", issueInvoice: "Émettre une facture", recordPayment: "Enregistrer un règlement", reconcile: "Rapprocher un règlement",
  statement: "Relevé", invoice: "Facture", payment: "Règlement", issuedOn: "Date d’émission", periodStart: "Début", periodEnd: "Fin",
  accountReceivable: "Compte client", accountRevenue: "Compte produit", accountTax: "Compte TVA", accountCash: "Compte trésorerie", method: "Mode",
  success: "Opération enregistrée. Actualisez pour afficher les nouveaux soldes.", validation: "Vérifiez les champs et les unités mineures.", forbidden: "Votre rôle ne permet pas cette opération.",
  conflict: "L’opération entre en conflit avec un solde ou une commande existante.", failed: "Échec sans modification des écritures.", pending: "Traitement…",
  loadError: "Impossible de charger les données de facturation.", noOrg: "Aucune organisation Sous-traitant comptable active n’est associée à ce compte.",
} as const;

const ar: { [K in keyof typeof fr]: string } = {
  title: "الفوترة والتسويات", description: "تابع المستحقات والكشوف والفواتير والمدفوعات والمطابقات الناتجة عن قيود غير قابلة للتعديل.",
  back: "لوحة التحكم", language: "Français", payables: "المبالغ المستحقة", statements: "الكشوف", invoices: "الفواتير والأرصدة", payments: "المدفوعات",
  allocations: "سجل المطابقات", emptyAllocations: "لا توجد مطابقة مسجلة.", immutableAllocation: "تخصيص محاسبي غير قابل للتعديل",
  allocated: "المخصص", unallocated: "غير المخصص", reconciliationHint: "تظهر فقط المدفوعات ذات الرصيد المتبقي والفواتير ذات الرصيد المستحق. يرفض الخادم أي تخصيص زائد.",
  commands: "العمليات المصرح بها", empty: "لا توجد بيانات مسجلة.", number: "الرقم", period: "الفترة", amount: "المبلغ", status: "الحالة", due: "الاستحقاق", paid: "المدفوع", outstanding: "الرصيد",
  date: "التاريخ", mission: "المهمة", reference: "المرجع", currency: "العملة", proof: "بصمة SHA-256", minor: "المبلغ بالوحدة الصغرى", event: "نوع الحدث",
  recordPayable: "تسجيل مبلغ مستحق", issueStatement: "إصدار كشف", issueInvoice: "إصدار فاتورة", recordPayment: "تسجيل دفعة", reconcile: "مطابقة دفعة",
  statement: "الكشف", invoice: "الفاتورة", payment: "الدفعة", issuedOn: "تاريخ الإصدار", periodStart: "البداية", periodEnd: "النهاية",
  accountReceivable: "حساب العميل", accountRevenue: "حساب الإيراد", accountTax: "حساب الضريبة", accountCash: "حساب الخزينة", method: "الطريقة",
  success: "تم تسجيل العملية. حدّث الصفحة لعرض الأرصدة الجديدة.", validation: "راجع الحقول والوحدات الصغرى.", forbidden: "دورك لا يسمح بهذه العملية.",
  conflict: "تتعارض العملية مع رصيد أو أمر موجود.", failed: "فشلت العملية دون تعديل القيود.", pending: "جارٍ التنفيذ…",
  loadError: "تعذر تحميل بيانات الفوترة.", noOrg: "لا توجد مؤسسة محاسبية لمقدم خدمة مرتبطة بهذا الحساب.",
};

export type BillingMessages = { [K in keyof typeof fr]: string };
export function getBillingMessages(locale: Locale): BillingMessages { return locale === "ar" ? ar : fr; }
