import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

type ReadFailure = "FORBIDDEN" | "UNAVAILABLE" | "INVALID_RESPONSE" | "NOT_FOUND";

export function AdminReadError({ locale, reason, retryHref, area = "organizations" }: { locale: Locale; reason: ReadFailure; retryHref: string; area?: "organizations" | "workQueue" }) {
  const ar = locale === "ar";
  const forbidden = reason === "FORBIDDEN";
  const secondary = area === "workQueue";
  return <Alert variant="destructive" dir={ar ? "rtl" : "ltr"}>
    <AlertTitle>{forbidden ? (ar ? "الوصول غير مسموح" : "Accès non autorisé") : secondary ? (ar ? "تعذر تحميل قائمة المعالجة" : "File de traitement indisponible") : (ar ? "تعذر تحميل البيانات" : "Chargement indisponible")}</AlertTitle>
    <AlertDescription>
      <p>{forbidden
        ? (ar ? "لا تسمح هذه الجلسة بعرض هذه البيانات. تحقق من صلاحياتك ومن التحقق الأمني لحسابك." : "Cette session ne permet pas de consulter ces données. Vérifiez vos habilitations et la vérification de sécurité de votre compte.")
        : secondary ? (ar ? "تظل قائمة المؤسسات متاحة، لكن تعذر تحميل بعض الإجراءات المطلوب معالجتها." : "La liste des entreprises reste consultable, mais certaines actions à traiter n’ont pas pu être chargées.") : (ar ? "تعذر استرجاع البيانات. لا يمكن اعتبار القائمة فارغة. يمكنك إعادة المحاولة مع الاحتفاظ بالتصفية الحالية." : "Les données n’ont pas pu être récupérées. La liste ne peut pas être considérée comme vide. Vous pouvez réessayer en conservant vos filtres.")}</p>
      {forbidden
        ? <a className="admin-soft-cta" href={connexionHref(locale, { next: retryHref })}>{ar ? "التحقق من الاتصال" : "Vérifier ma connexion"}</a>
        : <a className="admin-soft-cta" href={retryHref}>{ar ? "إعادة المحاولة" : "Réessayer"}</a>}
    </AlertDescription>
  </Alert>;
}
