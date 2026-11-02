import Link from "next/link";
import { actorCopy } from "@/modules/admin/data/spaces/actors-copy";
import type { ActorUserResult } from "@/modules/admin/data/spaces/actors-repository";
import { AdminAppShell } from "@/modules/admin/ui/admin-app-shell";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export function AdminActorLoadError({ locale, userId, roles = false, reason, space }: {
  locale: Locale;
  userId: string;
  roles?: boolean;
  reason: Extract<ActorUserResult, { status: "error" }>["reason"];
  space: { selectedQuery: string; selectedOrganizationId: string | null; userEmail: string | null };
}) {
  const forbidden = reason === "FORBIDDEN";
  const title = locale === "ar"
    ? forbidden ? "الوصول غير مسموح" : "تعذر تحميل الحساب"
    : forbidden ? "Accès non autorisé" : "Compte indisponible";
  const message = locale === "ar"
    ? forbidden
      ? "صلاحياتك لا تسمح بعرض هذا الحساب أو تعديل أدواره."
      : "تعذر تحميل بيانات الحساب. أعد المحاولة قبل أي تعديل."
    : forbidden
      ? "Vos habilitations ne permettent pas de consulter ce compte ou de modifier ses rôles."
      : "Les données du compte n’ont pas pu être chargées. Réessayez avant toute modification.";
  const path = `/administration/utilisateurs/${userId}${roles ? "/roles" : ""}${space.selectedQuery}`;
  const alternate = locale === "ar" ? "fr" : "ar";

  return (
    <AdminAppShell locale={locale} {...space} active="actors" actorCurrent="users"
      alternateHref={`/${alternate}${path}`} title={title}>
      <main className="client-page">
        <section className="client-card" role="alert">
          <h2>{title}</h2>
          <p>{message}</p>
          <div className="client-actions">
            {!forbidden && <a className="client-ghost-link" href={`/${locale}${path}`}>{locale === "ar" ? "إعادة المحاولة" : "Réessayer"}</a>}
            <Link className="client-ghost-link" href={`/${locale}/administration/utilisateurs${space.selectedQuery}`}>
              {actorCopy(locale).usersTitle}
            </Link>
          </div>
        </section>
      </main>
    </AdminAppShell>
  );
}
