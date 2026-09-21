import { notFound, redirect } from "next/navigation";
import { Badge } from "@/modules/shared/ui/badge";
import { createInternalMessagingRepository } from "@/modules/shared/lib/internal-messaging/server-repository";
import { resolveWorkspaceShell } from "@/modules/shared/lib/connected-space/workspace-shell";
import { isLocale, type Locale } from "@/modules/shared/lib/i18n/locale";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { MessagesBoard, SpaceActions } from "@/modules/client/screens/spaces/boards";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { providerCopy } from "@/modules/provider/data/spaces/copy";
import { ProviderActions, ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";
import { OpenThreadForm, SendMessageForm } from "./messaging-forms";
import { getMessagingMessages } from "./messages";

function date(value: string, locale: Locale) {
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short", timeZone: "Africa/Casablanca" }).format(new Date(value));
}

function ConversationPanel({
  locale,
  m,
  result,
}: {
  locale: Locale;
  m: ReturnType<typeof getMessagingMessages>;
  result: Awaited<ReturnType<Awaited<ReturnType<typeof createInternalMessagingRepository>>["load"]>>;
}) {
  if (result.status === "error") {
    return <p role="alert">{m.loadError}</p>;
  }
  if (result.value.conversation) {
    return (
      <div className="space-y-4">
        <header className="client-priority-head">
          <h2>{result.value.conversation.thread.subject}</h2>
          <Badge variant="outline">{m.policy}</Badge>
        </header>
        <ol className="client-feed">
          {result.value.conversation.messages.map((message) => (
            <li key={message.id}>
              <span>
                <strong>{message.sender_alias === "CLIENT" ? m.client : m.provider}</strong>
                <small>{date(message.created_at, locale)}</small>
                <p>{message.body}</p>
              </span>
            </li>
          ))}
        </ol>
        <SendMessageForm
          threadId={result.value.conversation.thread.id}
          senderOrganizationId={result.value.conversation.thread.participant_organization_id}
          locale={locale}
          m={m}
          locked={result.value.conversation.thread.status === "LOCKED"}
        />
      </div>
    );
  }
  return (
    <div className="space-y-4">
      <OpenThreadForm options={result.value.options} locale={locale} m={m} />
      <p>{m.choose}</p>
    </div>
  );
}

export default async function MessagingPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ fil?: string; organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const [result, workspaceShell] = await Promise.all([
    (await createInternalMessagingRepository()).load(query.fil),
    resolveWorkspaceShell(space.selectedOrganizationId),
  ]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const m = getMessagingMessages(locale);
  const c = spaceCopy(locale);
  const threads =
    result.status === "success"
      ? result.value.inbox.map((thread) => ({
          id: thread.id,
          title: thread.subject,
          meta: thread.counterparty_alias === "CLIENT" ? m.client : m.provider,
          href: `/${locale}/messagerie?fil=${thread.id}${space.selectedOrganizationId ? `&organizationId=${space.selectedOrganizationId}` : ""}`,
        }))
      : [];

  const board = (
    <MessagesBoard locale={locale} query={space.selectedQuery} threads={threads} organizationName={space.organizationName}>
      <ConversationPanel locale={locale} m={m} result={result} />
    </MessagesBoard>
  );

  if (workspaceShell === "provider") {
    const p = providerCopy(locale);
    return (
      <ProviderAppShell
        locale={locale}
        selectedQuery={space.selectedQuery}
        selectedOrganizationId={space.selectedOrganizationId}
        userEmail={space.userEmail}
        active="messages"
        title={m.title}
        lead={m.description}
        kicker={p.kicker}
        actions={<ProviderActions href={`/${locale}/messagerie${space.selectedQuery}`} label={m.open} />}
      >
        {board}
      </ProviderAppShell>
    );
  }

  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      active="messages"
      title={c.msgTitle}
      lead={c.msgLead}
      kicker={c.kicker}
      actions={<SpaceActions href={`/${locale}/messagerie${space.selectedQuery}`} label={c.newMessage} />}
    >
      {board}
    </ClientAppShell>
  );
}
