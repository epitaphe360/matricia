import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { mfaRequiredMessage } from "@/modules/shared/lib/account-security/platform-access";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { resolveAdminSpace } from "@/modules/admin/data/spaces/context";
import { isAdminSpaceId, isReservedView, type AdminSpaceId } from "@/modules/admin/data/spaces/admin-nav";
import { spaceSpec } from "@/modules/admin/data/spaces/screen-catalog";
import { findSpaceRow, loadAdminSpaceSnapshot } from "@/modules/admin/data/spaces/space-data";
import { AdminAppShell, AdminCrumb } from "@/modules/admin/ui/admin-app-shell";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { specialBoardCopy } from "@/modules/admin/data/spaces/special-copy";
import {
  SpaceCompareBoard,
  SpaceDecisionBoard,
  SpaceDetailBoard,
  SpaceHeaderActions,
  SpaceQueueBoard,
  SpaceWizardBoard,
} from "./queue-kit";
import { ConsultationSendBoard, DocumentReuseBoard, NotificationPreferencesBoard, SpecialBoardActions } from "./special-boards";
import { ProvidersPanel } from "@/modules/admin/screens/providers/providers-panel";
import { getAdminProviderMessages } from "@/modules/admin/screens/providers/messages";
import { GovernanceDashboard } from "@/modules/admin/screens/gouvernance-franchise/governance-dashboard";
import { getAdminGovernanceMessages } from "@/modules/admin/screens/gouvernance-franchise/messages";
import { DocumentVaultPanel } from "./document-vault-panel";

export async function renderAdminSpacePage({
  locale: localeParam,
  space: spaceParam,
  itemId,
  action,
  organizationId,
  q,
}: {
  locale: string;
  space: string;
  itemId?: string;
  action?: string;
  organizationId?: string;
  q?: string;
}) {
  if (!isLocale(localeParam) || !isAdminSpaceId(spaceParam)) notFound();
  const locale = localeParam;
  const space: AdminSpaceId = spaceParam === "territoires" && itemId === "validations" ? "gouvernance" : spaceParam;
  if (space === "gouvernance" && spaceParam === "territoires") {
    itemId = undefined;
    action = undefined;
  }
  const admin = await resolveAdminSpace({ locale, organizationId });
  if (admin.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const snapshot = await loadAdminSpaceSnapshot(locale, space, admin.selectedQuery);
  const spec = spaceSpec(space);
  const alternate = locale === "ar" ? "fr" : "ar";
  const reserved = itemId && isReservedView(itemId) ? itemId : null;
  const view = action ?? reserved ?? (itemId ? "detail" : "queue");
  const row = itemId && !reserved ? findSpaceRow(snapshot, itemId) : null;

  const groupLabel = spec.nav === "actors"
    ? (locale === "ar" ? "الفاعلون" : "Acteurs")
    : (locale === "ar" ? "المسار المهني" : "Parcours métier");
  const groupHref = spec.nav === "actors"
    ? `/${locale}/administration/entreprises${admin.selectedQuery}`
    : `/${locale}/administration/diagnostics${admin.selectedQuery}`;

  const crumbItems: Array<{ href?: string; label: string }> = [
    { href: groupHref, label: groupLabel },
    { href: view === "queue" ? undefined : `/${locale}/administration/${space}${admin.selectedQuery}`, label: spec.title(locale) },
  ];
  if (row) crumbItems.push({ label: row.title });
  if (reserved === "nouvelle" || reserved === "preparer") crumbItems.push({ label: spec.createLabel?.(locale) ?? spec.title(locale) });
  if (reserved === "comparer") crumbItems.push({ label: locale === "ar" ? "مقارنة" : "Comparer" });
  if (reserved === "preferences") crumbItems.push({ label: specialBoardCopy(locale, "preferences").crumb });
  if (action) crumbItems.push({ label: action === "consultation" ? specialBoardCopy(locale, "consultation").crumb : action === "reutilisation" ? specialBoardCopy(locale, "reuse").crumb : actionLabel(locale, action) });

  const specialKind = action === "consultation"
    ? "consultation"
    : reserved === "reutilisation" || action === "reutilisation"
      ? "reuse"
      : reserved === "preferences" || action === "preferences"
        ? "preferences"
        : null;
  const special = specialKind ? specialBoardCopy(locale, specialKind) : null;

  let body;
  if (view === "queue") {
    body = (
      <SpaceQueueBoard locale={locale} query={admin.selectedQuery} space={space} rows={snapshot.rows} treat={snapshot.treat} search={q}>
        {space === "providers" && snapshot.providers ? (
          <details className="client-ops">
            <summary>{getAdminProviderMessages(locale).title}</summary>
            <ProvidersPanel dashboard={snapshot.providers} locale={locale} messages={getAdminProviderMessages(locale)} keys={providerKeys(snapshot.providers)} />
          </details>
        ) : null}
        {space === "documents" ? <DocumentVaultPanel locale={locale} /> : null}
        {(space === "territoires" || space === "gouvernance" || space === "franchises") && snapshot.governance ? (
          <details className="client-ops">
            <summary>{getAdminGovernanceMessages(locale).title}</summary>
            <GovernanceDashboard dashboard={snapshot.governance} locale={locale} messages={getAdminGovernanceMessages(locale)} />
          </details>
        ) : null}
      </SpaceQueueBoard>
    );
  } else if (reserved === "comparer") {
    body = <SpaceCompareBoard locale={locale} query={admin.selectedQuery} space={space} rows={snapshot.rows} />;
  } else if (reserved === "preferences" || action === "preferences") {
    body = <NotificationPreferencesBoard locale={locale} query={admin.selectedQuery} templates={snapshot.supervision?.templates ?? []} />;
  } else if (reserved === "reutilisation" || action === "reutilisation") {
    body = <DocumentReuseBoard locale={locale} query={admin.selectedQuery} row={row} />;
  } else if (
    reserved === "nouvelle"
    || reserved === "preparer"
    || action === "modifier"
  ) {
    body = <SpaceWizardBoard locale={locale} query={admin.selectedQuery} space={space} />;
  } else if (action === "consultation") {
    body = row
      ? <ConsultationSendBoard locale={locale} query={admin.selectedQuery} row={row} />
      : <MissingRecord locale={locale} space={space} query={admin.selectedQuery} />;
  } else if (action === "decision" || action === "revue" || action === "activation" || action === "activer" || action === "cycle") {
    body = row
      ? <SpaceDecisionBoard locale={locale} query={admin.selectedQuery} space={space} row={row} />
      : <MissingRecord locale={locale} space={space} query={admin.selectedQuery} />;
  } else if (row) {
    body = <SpaceDetailBoard locale={locale} query={admin.selectedQuery} space={space} row={row} />;
  } else {
    body = <MissingRecord locale={locale} space={space} query={admin.selectedQuery} />;
  }

  return (
    <AdminAppShell
      locale={locale}
      selectedQuery={admin.selectedQuery}
      selectedOrganizationId={admin.selectedOrganizationId}
      userEmail={admin.userEmail}
      active={spec.nav}
      actorCurrent={spec.nav === "actors" ? spec.current : undefined}
      parcoursCurrent={spec.nav === "parcours" ? spec.current : undefined}
      searchAction={`/${locale}/administration/${space}`}
      searchPlaceholder={spec.search(locale)}
      alternateHref={`/${alternate}/administration/${space}${itemId ? `/${itemId}` : ""}${action ? `/${action}` : ""}${admin.selectedQuery}`}
      crumb={<AdminCrumb locale={locale} query={admin.selectedQuery} items={crumbItems} />}
      title={
        special
          ? special.title
          : reserved === "nouvelle" || reserved === "preparer"
            ? (spec.createLabel?.(locale) ?? spec.title(locale))
            : reserved === "comparer"
              ? (locale === "ar" ? "مقارنة العروض" : "Comparer les offres")
              : row && view !== "queue"
                ? `${spec.title(locale)} — ${row.title}`
                : spec.title(locale)
      }
      lead={special?.lead ?? spec.lead(locale)}
      kicker={row ? row.status : undefined}
      actions={specialKind ? <SpecialBoardActions locale={locale} kind={specialKind} /> : <SpaceHeaderActions locale={locale} query={admin.selectedQuery} spec={spec} />}
    >
      {snapshot.reason === "MFA_REQUIRED" ? (
        <Alert variant="destructive">
          <AlertTitle>{mfaRequiredMessage(locale)}</AlertTitle>
          <AlertDescription>{locale === "ar" ? "الملفات تبقى مخفية حتى تفعيل العامل الثاني." : "Les files restent masquées tant que le second facteur n’est pas actif."}</AlertDescription>
        </Alert>
      ) : null}
      {snapshot.reason === "FORBIDDEN" && snapshot.rows.length === 0 ? (
        <Alert variant="destructive">
          <AlertTitle>{locale === "ar" ? "وصول غير مسموح" : "Accès non autorisé"}</AlertTitle>
          <AlertDescription>{locale === "ar" ? "دورك لا يسمح بهذا الإشراف." : "Votre rôle ne permet pas cet accès."}</AlertDescription>
        </Alert>
      ) : null}
      {snapshot.reason === "UNAVAILABLE" || snapshot.reason === "INVALID_RESPONSE" ? (
        <Alert>
          <AlertTitle>{locale === "ar" ? "غير متاح" : "Indisponible"}</AlertTitle>
          <AlertDescription>
            <Link href={`/${locale}/administration/${space}`}>{locale === "ar" ? "إعادة المحاولة" : "Réessayer"}</Link>
          </AlertDescription>
        </Alert>
      ) : null}
      {body}
    </AdminAppShell>
  );
}

function MissingRecord({ locale, space, query }: { locale: "fr" | "ar"; space: string; query: string }) {
  return (
    <main className="client-page">
      <article className="client-empty">
        <p>{locale === "ar" ? "تعذر فتح هذا الملف." : "Ce dossier n’est pas accessible avec vos droits actuels."}</p>
        <Link href={`/${locale}/administration/${space}${query}`} className="client-ghost-link">{locale === "ar" ? "العودة إلى القائمة" : "Retour à la liste"}</Link>
      </article>
    </main>
  );
}

function actionLabel(locale: "fr" | "ar", action: string) {
  const map: Record<string, [string, string]> = {
    decision: ["Décision", "قرار"],
    revue: ["Revue", "مراجعة"],
    activation: ["Activation", "تفعيل"],
    activer: ["Activer", "تفعيل"],
    consultation: ["Consultation", "استشارة"],
    cycle: ["Démarrage et clôture", "الانطلاق والإغلاق"],
    modifier: ["Modifier", "تعديل"],
    reutilisation: ["Réutilisation", "إعادة استخدام"],
  };
  const pair = map[action];
  return pair ? (locale === "ar" ? pair[1] : pair[0]) : action;
}

function providerKeys(dashboard: { providers: Array<{ organizationId: string }>; documents: Array<{ id: string }>; services: Array<{ id: string }> }) {
  const keys: Record<string, string> = {
    statement: crypto.randomUUID(),
    invoice: crypto.randomUUID(),
    payment: crypto.randomUUID(),
    reconcile: crypto.randomUUID(),
    credit: crypto.randomUUID(),
    plan: crypto.randomUUID(),
    collection: crypto.randomUUID(),
    advance: crypto.randomUUID(),
  };
  for (const provider of dashboard.providers) keys[`company:${provider.organizationId}`] = crypto.randomUUID();
  for (const document of dashboard.documents) keys[`document:${document.id}`] = crypto.randomUUID();
  for (const service of dashboard.services) keys[`qualification:${service.id}`] = crypto.randomUUID();
  return keys;
}
