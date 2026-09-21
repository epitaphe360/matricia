import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/modules/shared/ui/alert";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { loadNotificationCenter } from "@/modules/shared/lib/notifications/repository";
import { ConnectedAppShell } from "@/modules/shared/ui/connected-app-shell";
import { getNotificationMessages } from "./messages";
import { NotificationsPanel } from "./notifications-panel";

export default async function NotificationsPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const m = getNotificationMessages(locale);
  const result = await loadNotificationCenter(locale);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  return (
    <ConnectedAppShell
      locale={locale}
      organizationId={query.organizationId}
      title={m.title}
      lead={m.description}
      clientActive="messages"
      providerActive="messages"
      franchiseActive="messages"
    >
      {result.status === "error" ? (
        <Alert variant={result.reason === "NO_ORGANIZATION" ? "default" : "destructive"}>
          <AlertTitle>{result.reason === "NO_ORGANIZATION" ? m.noOrg : m.loadError}</AlertTitle>
          <AlertDescription>{result.reason}</AlertDescription>
        </Alert>
      ) : (
        <NotificationsPanel dashboard={result.dashboard} locale={locale} m={m} />
      )}
    </ConnectedAppShell>
  );
}
