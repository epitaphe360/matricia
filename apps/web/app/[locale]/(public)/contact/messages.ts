import type { Locale } from "@/modules/shared/lib/i18n/locale";

const fr = {
  eyebrow: "Contact",
  title: "Échangeons ensemble",
  description: "Une question, un besoin d’accompagnement ou une opportunité de collaboration ? Notre équipe vous répond dans les meilleurs délais.",
  serviceTitle: "Commencer par un diagnostic",
  serviceText: "Répondez à quelques questions pour faire émerger vos priorités et identifier le bon point de départ.",
  serviceAction: "Analyser mon entreprise",
  needTitle: "Décrire un besoin précis",
  needText: "Vous savez déjà ce que vous souhaitez améliorer ? Décrivez le résultat attendu sans choisir dans un catalogue.",
  needAction: "Décrire mon besoin",
  accountTitle: "Demande sécurisée",
  accountText: "Connectez-vous pour créer une demande, conserver son historique et échanger dans le périmètre de votre organisation.",
  accountAction: "Se connecter",
  noForm: "Aucune information sensible n’est demandée sur cette page publique. Les échanges détaillés commencent après connexion.",
};

const ar: typeof fr = {
  eyebrow: "تواصل مع ماتريسيا",
  title: "لنتحدث عن احتياجك",
  description: "لحماية معلوماتك وضمان متابعة قابلة للتدقيق، تتم معالجة الطلبات المفصلة من خلال مساحتك الآمنة.",
  serviceTitle: "ابدأ بالتشخيص",
  serviceText: "أجب عن بعض الأسئلة لإبراز أولوياتك وتحديد نقطة البداية المناسبة.",
  serviceAction: "تحليل مؤسستي",
  needTitle: "صف احتياجاً محدداً",
  needText: "هل تعرف مسبقاً ما الذي تريد تحسينه؟ صف النتيجة المنتظرة دون الاختيار من دليل.",
  needAction: "وصف احتياجي",
  accountTitle: "طلب آمن",
  accountText: "سجل الدخول لإنشاء طلب والاحتفاظ بسجله والتواصل ضمن نطاق مؤسستك.",
  accountAction: "تسجيل الدخول",
  noForm: "لا تُطلب أي معلومات حساسة في هذه الصفحة العامة. تبدأ المراسلات المفصلة بعد تسجيل الدخول.",
};

export function getContactMessages(locale: Locale) {
  return locale === "ar" ? ar : fr;
}
