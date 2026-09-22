import Link from "next/link";
import { OpenThreadForm, SendMessageForm } from "@/app/[locale]/messagerie/messaging-forms";
import { getMessagingMessages } from "@/app/[locale]/messagerie/messages";
import { getNotificationMessages } from "@/app/[locale]/notifications/messages";
import type { InboxThread, ThreadConversation, ThreadOption } from "@/modules/shared/lib/internal-messaging/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

function date(value: string, locale: Locale) {
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short", timeZone: "Africa/Casablanca" }).format(new Date(value));
}

export type ProviderInboxNotification = {
  id: string;
  subject: string;
  createdAt: string;
  href: string | null;
  unread: boolean;
};

export function ProviderInboxBoard({
  locale,
  query,
  threads,
  conversation,
  options,
  preferredRfqId,
  notifications = [],
}: {
  locale: Locale;
  query: string;
  threads: InboxThread[];
  conversation: ThreadConversation | null;
  options: ThreadOption[];
  preferredRfqId?: string;
  notifications?: readonly ProviderInboxNotification[];
}) {
  const m = getMessagingMessages(locale);
  const n = getNotificationMessages(locale);
  const filteredOptions = preferredRfqId ? options.filter((item) => item.rfqId === preferredRfqId) : options;
  const openOptions = filteredOptions.length > 0 ? filteredOptions : options;
  const empty = locale === "ar" ? "لا توجد محادثة مرتبطة باستشارة." : "Aucune conversation liée à une consultation.";
  return (
    <main className="client-page provider-workbench provider-messages">
      <header className="provider-workbench-hero">
        <div>
          <h2>{m.title}</h2>
          <p>{m.description}</p>
        </div>
      </header>
      <section className="provider-messages-grid" id="messages">
        <article className="client-card provider-thread-list">
          <header><h2>{m.threads}</h2></header>
          {threads.length === 0 ? <p>{m.empty}</p> : (
            <ul className="client-feed">
              {threads.map((thread) => (
                <li key={thread.id}>
                  <Link
                    href={`/${locale}/sous-traitant/messages/${thread.id}${query}`}
                    className="provider-thread-link"
                    data-active={conversation?.thread.id === thread.id ? "true" : undefined}
                  >
                    <strong>{thread.subject}</strong>
                    <small>{thread.counterparty_alias === "CLIENT" ? m.client : m.provider} · {date(thread.last_message_at, locale)}</small>
                    <em>{thread.object_type}</em>
                  </Link>
                </li>
              ))}
            </ul>
          )}
          <OpenThreadForm
            options={openOptions}
            locale={locale}
            m={m}
            successBase={`/${locale}/sous-traitant/messages`}
            successSuffix={query}
          />
        </article>
        <article className="client-card provider-message-pane">
          {conversation ? (
            <>
              <header className="client-priority-head">
                <div>
                  <h3>{conversation.thread.subject}</h3>
                  <p>{m.privacy}</p>
                </div>
                <Link href={`/${locale}/sous-traitant/consultations/${conversation.thread.object_id}${query}`} className="client-text-link">{m.consultation}</Link>
              </header>
              <ol className="client-feed provider-message-thread">
                {conversation.messages.map((message) => (
                  <li key={message.id} data-mine={message.mine ? "true" : "false"}>
                    <span>
                      <strong>{message.sender_alias === "CLIENT" ? m.client : m.provider}</strong>
                      <small>{date(message.created_at, locale)}</small>
                      <p className={message.mine ? "provider-message-self" : undefined}>{message.body}</p>
                    </span>
                  </li>
                ))}
              </ol>
              <SendMessageForm
                threadId={conversation.thread.id}
                senderOrganizationId={conversation.thread.participant_organization_id}
                locale={locale}
                m={m}
                locked={conversation.thread.status === "LOCKED"}
              />
            </>
          ) : (
            <p>{threads.length === 0 ? empty : m.choose}</p>
          )}
        </article>
        <article className="client-card" id="notifications">
          <header className="client-priority-head">
            <h2>{n.center}</h2>
            <Link href={`/${locale}/notifications${query}`} className="client-text-link">{n.preferences}</Link>
          </header>
          {notifications.length === 0 ? <p role="status">{n.empty}</p> : (
            <ul className="client-feed">
              {notifications.map((item) => (
                <li key={item.id}>
                  <span>
                    <strong>{item.subject}</strong>
                    <small>{date(item.createdAt, locale)}{item.unread ? ` · ${n.unread}` : ""}</small>
                  </span>
                  <Link href={item.href ?? `/${locale}/notifications${query}`} className="client-text-link">{n.open}</Link>
                </li>
              ))}
            </ul>
          )}
        </article>
      </section>
    </main>
  );
}
