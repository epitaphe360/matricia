import type { Locale } from "@/lib/i18n/locale";

const fr = {
  eyebrow: "Échanger avec Matricia",
  title: "Parlons de votre besoin",
  description: "Pour protéger vos informations et assurer un suivi traçable, les demandes détaillées sont prises en charge depuis votre espace sécurisé.",
  serviceTitle: "Découvrir les services",
  serviceText: "Explorez les 10 bibliothèques et les 200 services du catalogue de référence avant de préciser votre besoin.",
  serviceAction: "Voir les services",
  accountTitle: "Demande sécurisée",
  accountText: "Connectez-vous pour créer une demande, conserver son historique et échanger dans le périmètre de votre organisation.",
  accountAction: "Se connecter",
  noForm: "Aucun formulaire public ne collecte de données personnelles sur cette page.",
};

const ar: typeof fr = {
  eyebrow: "تواصل مع ماتريسيا",
  title: "لنتحدث عن احتياجك",
  description: "لحماية معلوماتك وضمان متابعة قابلة للتدقيق، تتم معالجة الطلبات المفصلة من خلال مساحتك الآمنة.",
  serviceTitle: "اكتشف الخدمات",
  serviceText: "استكشف المكتبات العشر والخدمات المئتين في الكتالوج المرجعي قبل تحديد احتياجك.",
  serviceAction: "عرض الخدمات",
  accountTitle: "طلب آمن",
  accountText: "سجل الدخول لإنشاء طلب والاحتفاظ بسجله والتواصل ضمن نطاق مؤسستك.",
  accountAction: "تسجيل الدخول",
  noForm: "لا تجمع هذه الصفحة أي بيانات شخصية عبر نموذج عام.",
};

export function getContactMessages(locale: Locale) {
  return locale === "ar" ? ar : fr;
}
