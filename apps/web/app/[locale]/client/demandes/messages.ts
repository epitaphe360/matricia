import type { Locale } from "@/lib/i18n/locale";

const fr = {
  navigation:"Navigation demandes", back:"Tableau de bord", language:"العربية", eyebrow:"Espace Client",
  title:"Demandes et devis", description:"Décrivez votre besoin, ouvrez une consultation et comparez des devis normalisés sans exposer les offres concurrentes aux prestataires.",
  newRequest:"Nouvelle demande", empty:"Aucune demande pour le moment.", readOnly:"Consultation uniquement : votre rôle permet de lire les demandes et comparaisons sans les modifier.",
  status:"Statut", budget:"Budget indicatif", quotes:"Devis reçus", created:"Créée", view:"Voir la demande", unavailable:"Non renseigné", loadError:"Impossible de charger vos demandes.", retry:"Réessayer",
  createTitle:"Préparer une demande", createDescription:"Reprenez une priorité confirmée, précisez votre besoin et enregistrez un brouillon avant toute consultation.",
  contextDerived:"Le service, le questionnaire et leurs versions sont retrouvés et contrôlés côté serveur.", contextRequired:"Choisissez d’abord une priorité dans votre analyse, ou décrivez votre besoin pour recevoir des suggestions adaptées.", contextError:"Cette priorité n’est plus disponible, n’est pas complète ou n’appartient pas à l’organisation active.", openAnalysis:"Voir mes analyses", describeNeed:"Décrire mon besoin", suggestedSolution:"Solution suggérée",
  organization:"Organisation cliente", libraryId:"Bibliothèque", serviceId:"Service", questionnaireId:"Version du questionnaire", catalogHash:"Empreinte du catalogue", questionnaireHash:"Empreinte du questionnaire",
  need:"Besoin détaillé", urgency:"Urgence", desiredDate:"Date souhaitée", budgetAmount:"Budget MAD", budgetHelp:"Utilisez par exemple 15 000,00. Le montant est converti exactement, sans arrondi flottant.", region:"Région", reason:"Motif de création", confirm:"Je confirme l’exactitude de la demande", draftNotice:"Cette action enregistre un brouillon. Les prestataires ne sont contactés qu’après validation explicite des informations.",
  create:"Enregistrer la demande", createDraft:"Enregistrer le brouillon", creating:"Enregistrement…", validation:"Vérifiez les champs indiqués.", saved:"Brouillon enregistré.", detailTitle:"Détail de la demande",
  urgencies:{LOW:"Peu urgente",NORMAL:"Normale",HIGH:"Urgente",CRITICAL:"Critique"},
  workflow:"Pilotage de la consultation", markReady:"Valider les informations", runMatch:"Rechercher des prestataires", openRfq:"Ouvrir la consultation", matchingRun:"Identifiant du matching", deadline:"Date limite", panelSize:"Taille du panel",
  comparison:"Comparer les devis", comparisonTitle:"Comparaison normalisée", comparisonDescription:"Les totaux viennent du serveur, utilisent la même devise et une fiscalité marocaine versionnée.",
  compare:"Générer la comparaison", refreshComparison:"Actualiser la comparaison", comparing:"Comparaison…", snapshot:"Comparaison figée", noComparison:"Aucune comparaison figée n’est encore disponible.",
  rank:"Classement prix", total:"Total TTC", subtotal:"Sous-total HT", tax:"TVA", recurring:"Récurrent HT", duration:"Durée", days:"jours", deliverables:"Livrables", validUntil:"Valable jusqu’au",
  select:"Sélectionner ce devis", expiredQuote:"Ce devis a expiré et ne peut plus être sélectionné.", selected:"Devis sélectionné. Le contrat reprendra cette version immuable.",
  actionError:"L’opération n’a pas abouti. Actualisez les données avant de réessayer.", privacy:"Chaque prestataire ne voit que sa propre invitation et sa propre offre.",
  statuses:{DRAFT:"Brouillon",INFORMATION_REQUIRED:"Informations requises",READY:"Prête",MATCHING:"Matching",RFQ_OPEN:"Consultation ouverte",QUOTES_RECEIVED:"Devis reçus",CLIENT_REVIEW:"Revue client",PROVIDER_SELECTED:"Prestataire sélectionné",CONTRACT_PENDING:"Contrat en préparation",CONTRACTED:"Contractée",CANCELLED:"Annulée",EXPIRED:"Expirée",NO_PROVIDER_AVAILABLE:"Aucun prestataire disponible"},
} as const;

const ar = {
  ...fr,
  navigation:"التنقل في الطلبات", back:"لوحة التحكم", language:"Français", eyebrow:"فضاء العميل", title:"الطلبات والعروض",
  description:"صِف حاجتك وافتح طلب عروض وقارن العروض الموحّدة دون كشف عروض المنافسين لمقدمي الخدمات.",
  newRequest:"طلب جديد", empty:"لا توجد طلبات حالياً.", readOnly:"للاطلاع فقط: يسمح دورك بقراءة الطلبات والمقارنات دون تعديلها.",
  status:"الحالة", budget:"الميزانية التقديرية", quotes:"العروض المستلمة", created:"تاريخ الإنشاء", view:"عرض الطلب", unavailable:"غير محدد", loadError:"تعذر تحميل الطلبات.", retry:"إعادة المحاولة",
  createTitle:"إعداد طلب", createDescription:"استرجع أولوية مؤكدة وحدد حاجتك واحفظ مسودة قبل أي استشارة.",
  contextDerived:"يتم استرجاع الخدمة والاستبيان ونسخهما والتحقق منها على الخادم.", contextRequired:"اختر أولا أولوية من تحليلك أو صف حاجتك للحصول على اقتراحات مناسبة.", contextError:"لم تعد هذه الأولوية متاحة أو مكتملة أو لا تنتمي إلى المنظمة النشطة.", openAnalysis:"عرض تحليلاتي", describeNeed:"وصف حاجتي", suggestedSolution:"الحل المقترح",
  organization:"المنظمة العميلة", libraryId:"المكتبة", serviceId:"الخدمة", questionnaireId:"نسخة الاستبيان", catalogHash:"بصمة الكتالوج", questionnaireHash:"بصمة الاستبيان",
  need:"وصف الحاجة", urgency:"الاستعجال", desiredDate:"التاريخ المطلوب", budgetAmount:"الميزانية بالدرهم", budgetHelp:"استخدم مثلا 15 000,00. يتم تحويل المبلغ بدقة دون تقريب عائم.", region:"المنطقة", reason:"سبب الإنشاء", confirm:"أؤكد صحة الطلب", draftNotice:"يحفظ هذا الإجراء مسودة. لا يتم الاتصال بمقدمي الخدمات إلا بعد تأكيد المعلومات صراحة.",
  create:"حفظ الطلب", createDraft:"حفظ المسودة", creating:"جارٍ الحفظ…", validation:"تحقق من الحقول المحددة.", saved:"تم حفظ المسودة.", detailTitle:"تفاصيل الطلب",
  urgencies:{LOW:"غير مستعجل",NORMAL:"عادي",HIGH:"مستعجل",CRITICAL:"حرج"},
  workflow:"إدارة طلب العروض", markReady:"تأكيد اكتمال المعلومات", runMatch:"البحث عن مقدمي الخدمات", openRfq:"فتح طلب العروض", matchingRun:"معرف المطابقة", deadline:"الموعد النهائي", panelSize:"حجم القائمة",
  comparison:"مقارنة العروض", comparisonTitle:"مقارنة موحّدة", comparisonDescription:"الإجماليات محسوبة على الخادم وبعملة واحدة وبقواعد ضريبية مغربية مؤرخة.",
  compare:"إنشاء المقارنة", refreshComparison:"تحديث المقارنة", comparing:"جارٍ إعداد المقارنة…", snapshot:"مقارنة محفوظة", noComparison:"لا توجد مقارنة محفوظة بعد.",
  rank:"ترتيب السعر", total:"الإجمالي مع الضريبة", subtotal:"المجموع دون الضريبة", tax:"الضريبة", recurring:"المتكرر دون الضريبة", duration:"المدة", days:"أيام", deliverables:"المخرجات", validUntil:"صالح حتى",
  select:"اختيار هذا العرض", expiredQuote:"انتهت صلاحية هذا العرض ولا يمكن اختياره.", selected:"تم اختيار العرض وستعتمد العقود هذه النسخة غير القابلة للتغيير.",
  actionError:"لم تنجح العملية. حدّث البيانات ثم أعد المحاولة.", privacy:"كل مقدم خدمة يرى دعوته وعرضه فقط.",
  statuses:{DRAFT:"مسودة",INFORMATION_REQUIRED:"معلومات مطلوبة",READY:"جاهز",MATCHING:"مطابقة",RFQ_OPEN:"طلب العروض مفتوح",QUOTES_RECEIVED:"عروض مستلمة",CLIENT_REVIEW:"مراجعة العميل",PROVIDER_SELECTED:"تم اختيار مقدم الخدمة",CONTRACT_PENDING:"العقد قيد الإعداد",CONTRACTED:"متعاقد",CANCELLED:"ملغى",EXPIRED:"منتهي",NO_PROVIDER_AVAILABLE:"لا يوجد مقدم خدمة"},
} as const;

export type ClientRfqMessages = { [K in Exclude<keyof typeof fr,"statuses"|"urgencies">]:string } & { statuses:Record<keyof typeof fr.statuses,string>;urgencies:Record<keyof typeof fr.urgencies,string> };
export function getClientRfqMessages(locale:Locale):ClientRfqMessages{return locale==="ar"?ar:fr;}
