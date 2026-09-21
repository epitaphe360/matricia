import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { clientDashboardCopy } from "@/modules/client/data/home/copy";
import { toClientPriorityRows, type ClientPriorityRow } from "@/modules/client/data/home/view-model";
import type { UserActionItem } from "@/modules/shared/lib/action-center/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export function RequiredActionsBoard({
  locale,
  items,
  organizationQuery,
  error,
}: {
  locale: Locale;
  items: readonly UserActionItem[];
  organizationQuery: string;
  error: boolean;
}) {
  const c = clientDashboardCopy[locale];
  const rows = toClientPriorityRows(items, locale, organizationQuery);
  if (error) {
    return <p role="alert" className="client-page">{c.snapshotError}</p>;
  }
  if (rows.length === 0) {
    return (
      <main className="client-page">
        <p>{c.actionsEmpty}</p>
      </main>
    );
  }
  const grouped = groupRows(rows);
  return (
    <main className="client-page client-action-file space-y-6">
      {grouped.map((group) => (
        <section key={group.kind} className="client-card" aria-labelledby={`actions-${group.kind}`}>
          <header>
            <h2 id={`actions-${group.kind}`}>{group.title}</h2>
            <small dir="ltr">{group.rows.length}</small>
          </header>
          <div className="client-treat">
            {group.rows.map((row) => (
              <Link key={row.id} href={row.href} className="client-treat-tile">
                <div>
                  <strong>{row.dossier}</strong>
                  <small>{row.owner}{row.dueAt ? ` · ${c.actionsDue} ${formatDue(row.dueAt, locale)}` : ""}</small>
                </div>
                <span>{row.cta}</span>
                <ArrowRight aria-hidden className="size-4 rtl:rotate-180" />
              </Link>
            ))}
          </div>
        </section>
      ))}
    </main>
  );
}

function groupRows(rows: ClientPriorityRow[]) {
  const order = [...new Set(rows.map((row) => row.situation))];
  return order.map((kind) => ({
    kind,
    title: rows.find((row) => row.situation === kind)?.title ?? kind,
    rows: rows.filter((row) => row.situation === kind),
  }));
}

function formatDue(value: string, locale: Locale): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium" }).format(date);
}
