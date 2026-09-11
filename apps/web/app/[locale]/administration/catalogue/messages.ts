import type { Locale } from "@/lib/i18n/locale";

export type BuilderMessages = {
  nav: string; back: string; language: string; eyebrow: string; title: string; description: string;
  selection: string; library: string; service: string; chooseLibrary: string; chooseService: string; open: string;
  noLibraries: string; noServices: string; unavailable: string; retry: string;
  questionnaireGapTitle: string; questionnaireGap: string;
  releaseTitle: string; releaseDescription: string; selectedContext: string;
  createTitle: string; releaseKey: string; sourceHash: string; centralApproval: string; approvalYes: string; approvalNo: string;
  confirmCreate: string; create: string; creating: string;
  addTitle: string; releaseId: string; objectType: string; objectId: string; versionId: string; contentHash: string;
  sortOrder: string; rowVersion: string; confirmAdd: string; add: string; adding: string;
  submitTitle: string; confirmSubmit: string; submit: string; submitting: string;
  successCreated: string; successAdded: string; successSubmitted: string; resultRelease: string; resultVersion: string; resultStatus: string;
  objectTypes: Record<"LIBRARY" | "CATEGORY" | "SUBCATEGORY" | "SERVICE" | "SERVICE_SUBCATEGORY_LINK", string>;
  entityStatuses: Record<"DRAFT" | "IN_REVIEW" | "APPROVED" | "PUBLISHED" | "RETIRED" | "ARCHIVED", string>;
  releaseStatuses: Record<"APPROVED" | "IN_REVIEW", string>;
  errors: { validation: string; unauthenticated: string; forbidden: string; unavailable: string };
};

const fr: BuilderMessages = {
  nav: "Navigation du gestionnaire de releases catalogue", back: "Retour au tableau de bord", language: "العربية",
  eyebrow: "Catalogue versionné", title: "Gestion des releases catalogue", description: "Préparez une release auditable à partir des identifiants et versions approuvés.",
  selection: "Contexte de travail", library: "Bibliothèque", service: "Service ciblé", chooseLibrary: "Choisir une bibliothèque", chooseService: "Choisir un service", open: "Ouvrir le contexte",
  noLibraries: "Aucune bibliothèque administrable n’est accessible.", noServices: "Aucun service accessible dans cette bibliothèque.", unavailable: "Le Builder ne peut pas charger ce contexte.", retry: "Réessayer",
  questionnaireGapTitle: "Composition de questionnaires non disponible", questionnaireGap: "Le backend expose la lecture et la publication, mais aucune commande authentifiée ne permet encore de créer ou modifier un questionnaire, ses questions, sections ou règles. Aucune saisie ne sera simulée dans cette interface.",
  releaseTitle: "Workflow de release", releaseDescription: "Les trois opérations ci-dessous appellent les commandes auditées existantes. Ajoutez uniquement des versions APPROVED et conservez le row version renvoyé après chaque étape.", selectedContext: "Contexte sélectionné",
  createTitle: "1. Créer le brouillon", releaseKey: "Clé de release", sourceHash: "Empreinte SHA-256 du bundle", centralApproval: "Approbation centrale requise", approvalYes: "Oui", approvalNo: "Non", confirmCreate: "Je confirme créer une release DRAFT pour cette bibliothèque.", create: "Créer la release", creating: "Création…",
  addTitle: "2. Ajouter un élément approuvé", releaseId: "Identifiant de release", objectType: "Type d’objet", objectId: "Identifiant de l’objet", versionId: "Identifiant de la version APPROVED", contentHash: "Empreinte SHA-256 du contenu", sortOrder: "Ordre", rowVersion: "Row version attendu", confirmAdd: "Je confirme l’identité, la version et l’empreinte de cet élément.", add: "Ajouter l’élément", adding: "Ajout…",
  submitTitle: "3. Soumettre la release", confirmSubmit: "Je confirme que l’arbre est complet et que les traductions arabes sont approuvées.", submit: "Soumettre pour validation", submitting: "Soumission…",
  successCreated: "Release DRAFT créée.", successAdded: "Élément ajouté à la release.", successSubmitted: "Release soumise avec succès.", resultRelease: "Release", resultVersion: "Nouvelle row version", resultStatus: "Statut",
  objectTypes: { LIBRARY: "Bibliothèque", CATEGORY: "Catégorie", SUBCATEGORY: "Sous-catégorie", SERVICE: "Service", SERVICE_SUBCATEGORY_LINK: "Lien service / sous-catégorie" },
  entityStatuses: { DRAFT: "Brouillon", IN_REVIEW: "En validation", APPROVED: "Approuvé", PUBLISHED: "Publié", RETIRED: "Retiré", ARCHIVED: "Archivé" },
  releaseStatuses: { APPROVED: "Approuvée", IN_REVIEW: "En validation" },
  errors: { validation: "Vérifiez les identifiants, empreintes, versions et confirmations.", unauthenticated: "Votre session a expiré.", forbidden: "Vous ne disposez pas des permissions catalogue requises.", unavailable: "La commande n’a pas abouti. Vérifiez l’état et la concurrence de version." },
};

const ar: BuilderMessages = {
  nav: "التنقل في إدارة إصدارات الدليل", back: "العودة إلى لوحة التحكم", language: "Français",
  eyebrow: "دليل بإصدارات", title: "إدارة إصدارات الدليل", description: "حضّر إصداراً قابلاً للتدقيق انطلاقاً من المعرفات والنسخ المعتمدة.",
  selection: "سياق العمل", library: "المكتبة", service: "الخدمة المستهدفة", chooseLibrary: "اختر مكتبة", chooseService: "اختر خدمة", open: "فتح السياق",
  noLibraries: "لا توجد مكتبة إدارية متاحة.", noServices: "لا توجد خدمة متاحة في هذه المكتبة.", unavailable: "تعذر تحميل سياق المنشئ.", retry: "إعادة المحاولة",
  questionnaireGapTitle: "تكوين الاستبيانات غير متاح", questionnaireGap: "توفر الواجهة الخلفية القراءة والنشر، لكنها لا توفر بعد أمراً موثقاً لإنشاء أو تعديل الاستبيان أو أسئلته أو أقسامه أو قواعده. لن تتم محاكاة أي حفظ في هذه الواجهة.",
  releaseTitle: "مسار إصدار الدليل", releaseDescription: "تستدعي العمليات الثلاث التالية الأوامر المدققة الموجودة. أضف نسخاً بحالة APPROVED فقط واحتفظ برقم الصف الناتج بعد كل خطوة.", selectedContext: "السياق المحدد",
  createTitle: "1. إنشاء المسودة", releaseKey: "مفتاح الإصدار", sourceHash: "بصمة SHA-256 للحزمة", centralApproval: "الموافقة المركزية مطلوبة", approvalYes: "نعم", approvalNo: "لا", confirmCreate: "أؤكد إنشاء إصدار DRAFT لهذه المكتبة.", create: "إنشاء الإصدار", creating: "جارٍ الإنشاء…",
  addTitle: "2. إضافة عنصر معتمد", releaseId: "معرف الإصدار", objectType: "نوع العنصر", objectId: "معرف العنصر", versionId: "معرف النسخة APPROVED", contentHash: "بصمة SHA-256 للمحتوى", sortOrder: "الترتيب", rowVersion: "رقم الصف المتوقع", confirmAdd: "أؤكد هوية العنصر ونسخته وبصمته.", add: "إضافة العنصر", adding: "جارٍ الإضافة…",
  submitTitle: "3. إرسال الإصدار", confirmSubmit: "أؤكد اكتمال الشجرة واعتماد الترجمات العربية.", submit: "إرسال للتحقق", submitting: "جارٍ الإرسال…",
  successCreated: "تم إنشاء إصدار DRAFT.", successAdded: "تمت إضافة العنصر إلى الإصدار.", successSubmitted: "تم إرسال الإصدار بنجاح.", resultRelease: "الإصدار", resultVersion: "رقم الصف الجديد", resultStatus: "الحالة",
  objectTypes: { LIBRARY: "المكتبة", CATEGORY: "الفئة", SUBCATEGORY: "الفئة الفرعية", SERVICE: "الخدمة", SERVICE_SUBCATEGORY_LINK: "رابط الخدمة والفئة الفرعية" },
  entityStatuses: { DRAFT: "مسودة", IN_REVIEW: "قيد المراجعة", APPROVED: "معتمد", PUBLISHED: "منشور", RETIRED: "مسحوب", ARCHIVED: "مؤرشف" },
  releaseStatuses: { APPROVED: "معتمد", IN_REVIEW: "قيد المراجعة" },
  errors: { validation: "تحقق من المعرفات والبصمات والإصدارات والتأكيدات.", unauthenticated: "انتهت صلاحية جلستك.", forbidden: "ليست لديك صلاحيات الدليل المطلوبة.", unavailable: "لم ينجح الأمر. تحقق من الحالة وتعارض النسخة." },
};

export function getBuilderMessages(locale: Locale): BuilderMessages { return locale === "ar" ? ar : fr; }
