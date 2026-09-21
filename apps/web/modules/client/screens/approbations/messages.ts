import type { Locale } from "@/modules/shared/lib/i18n/locale";

const fr = {
  title: "Approbations multi-personnes",
  intro: "Devis, contrats et paiements peuvent exiger plusieurs validations. Une décision n’exécute pas de paiement seule.",
  empty: "Aucune demande d’approbation n’est en attente pour cette organisation.",
  resource: "Objet",
  amount: "Montant",
  requestedAt: "Demandée le",
  status: "État",
  approve: "Approuver",
  reject: "Refuser",
  reason: "Motif",
  submit: "Enregistrer ma décision",
  pending: "Enregistrement…",
  mfaRequired: "La décision exige une authentification renforcée (AAL2) et un rôle prévu par la politique versionnée.",
  success: "Décision enregistrée. Le seuil d’approbations reste celui de la politique.",
  validation: "Vérifiez le motif (3 caractères minimum).",
  forbidden: "Votre rôle ou votre niveau d’authentification ne permet pas cette décision.",
  conflict: "Cette demande a changé. Actualisez la page.",
  failed: "La décision n’a pas pu être enregistrée.",
  statuses: { PENDING: "En attente", APPROVED: "Approuvée", REJECTED: "Refusée" },
};

const ar: typeof fr = {
  ...fr,
  title: "الموافقات متعددة الأشخاص",
  intro: "قد تتطلب العروض والعقود والمدفوعات عدة تصديقات. لا ينفذ القرار أي دفع بمفرده.",
  empty: "لا يوجد طلب موافقة معلّق لهذه المؤسسة.",
  resource: "الموضوع",
  amount: "المبلغ",
  requestedAt: "طُلب في",
  status: "الحالة",
  approve: "موافقة",
  reject: "رفض",
  reason: "السبب",
  submit: "تسجيل قراري",
  pending: "جارٍ التسجيل…",
  mfaRequired: "يتطلب القرار مصادقة معززة (AAL2) ودوراً منصوصاً عليه في السياسة المؤرخة.",
  success: "تم تسجيل القرار. يبقى حد الموافقات وفق السياسة.",
  validation: "تحقق من السبب (3 أحرف على الأقل).",
  forbidden: "دورك أو مستوى مصادقتك لا يسمح بهذا القرار.",
  conflict: "تغير هذا الطلب. حدّث الصفحة.",
  failed: "تعذر تسجيل القرار.",
  statuses: { PENDING: "معلّق", APPROVED: "مقبول", REJECTED: "مرفوض" },
};

export type ApprovalMessages = typeof fr;
export function getApprovalMessages(locale: Locale): ApprovalMessages {
  return locale === "ar" ? ar : fr;
}
