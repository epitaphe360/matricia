import { formatExactMoney } from "@/modules/shared/lib/contracts-missions/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { ApprovalDecisionForm } from "./decision-form";
import type { ApprovalMessages } from "./messages";
import type { ClientApprovalRequest } from "./model";

export function ClientApprovalsPanel({
  locale,
  items,
  messages,
}: {
  locale: Locale;
  items: ClientApprovalRequest[];
  messages: ApprovalMessages;
}) {
  return (
    <section className="client-card space-y-4" aria-labelledby="client-approvals">
      <header>
        <h2 id="client-approvals">{messages.title}</h2>
        <p>{messages.intro}</p>
      </header>
      {items.length === 0 ? <p>{messages.empty}</p> : (
        <ul className="space-y-4">
          {items.map((item) => (
            <li key={item.id} className="rounded-xl border p-4">
              <dl className="grid gap-2 text-sm sm:grid-cols-2">
                <div><dt className="text-muted-foreground">{messages.resource}</dt><dd dir="ltr">{item.resourceType} · {item.resourceId}</dd></div>
                <div><dt className="text-muted-foreground">{messages.status}</dt><dd>{messages.statuses[item.status]}</dd></div>
                <div><dt className="text-muted-foreground">{messages.amount}</dt><dd dir="ltr">{item.amountMinor && item.currency ? formatExactMoney(item.amountMinor, item.currency, locale) : "—"}</dd></div>
                <div><dt className="text-muted-foreground">{messages.requestedAt}</dt><dd><time dateTime={item.requestedAt}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(new Date(item.requestedAt))}</time></dd></div>
              </dl>
              {item.status === "PENDING" ? <ApprovalDecisionForm item={item} locale={locale} messages={messages} /> : null}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
