import type { Locale } from "@/lib/i18n/locale";

const copy = {
  fr: {
    brand: "Matricia",
    back: "Retour à l’accueil",
    panelEyebrow: "Votre parcours continue ici",
    panelTitle: "Retrouvez vos priorités et passez à l’action.",
    panelBody: "La connexion protège le contexte de votre diagnostic, de votre besoin et des échanges liés à votre organisation.",
    trust: ["Accès limité à votre organisation", "Historique et décisions traçables", "Parcours disponible en français et en arabe"],
    continuity: "Après connexion, vous reprendrez exactement là où vous vous êtes arrêté.",
    security: "Connexion chiffrée · Aucun mot de passe requis avec le code par courriel",
    resend: "Renvoyer le code",
    resent: "Si cette adresse est admissible, un nouveau code vient d’être envoyé.",
    loginTitle: "Vous avez déjà un compte ?",
    loginAction: "Se connecter",
    signupTitle: "Nouveau sur Matricia ?",
    signupAction: "Créer un compte",
    signupPageTitle: "Créez votre compte Matricia",
    signupPageDescription: "Validez votre adresse professionnelle, puis créez ou rejoignez le passeport de votre organisation.",
    clientAccount: "Compte Client",
    providerAccount: "Compte Sous-traitant",
  },
  ar: {
    brand: "ماتريسيا",
    back: "العودة إلى الرئيسية",
    panelEyebrow: "يستمر مسارك من هنا",
    panelTitle: "استرجع أولوياتك وانتقل إلى التنفيذ.",
    panelBody: "يحمي تسجيل الدخول سياق تشخيصك واحتياجك والمراسلات المرتبطة بمؤسستك.",
    trust: ["وصول محصور في مؤسستك", "سجل وقرارات قابلة للتتبع", "مسار متاح بالفرنسية والعربية"],
    continuity: "بعد تسجيل الدخول، ستتابع من النقطة التي توقفت عندها تماماً.",
    security: "اتصال مشفر · لا حاجة إلى كلمة مرور عند استخدام الرمز عبر البريد",
    resend: "إعادة إرسال الرمز",
    resent: "إذا كان العنوان مؤهلاً، فقد تم إرسال رمز جديد إليه.",
    loginTitle: "لديك حساب بالفعل؟",
    loginAction: "تسجيل الدخول",
    signupTitle: "جديد على ماتريسيا؟",
    signupAction: "إنشاء حساب",
    signupPageTitle: "أنشئ حسابك على ماتريسيا",
    signupPageDescription: "تحقق من بريدك المهني، ثم أنشئ جواز مؤسستك أو اطلب الانضمام إليها.",
    clientAccount: "حساب عميل",
    providerAccount: "حساب مقدم خدمات",
  },
} satisfies Record<Locale, { brand: string; back: string; panelEyebrow: string; panelTitle: string; panelBody: string; trust: readonly string[]; continuity: string; security: string; resend: string; resent: string; loginTitle: string; loginAction: string; signupTitle: string; signupAction: string; signupPageTitle: string; signupPageDescription: string; clientAccount: string; providerAccount: string }>;

export function getLoginMessages(locale: Locale) {
  return copy[locale];
}
