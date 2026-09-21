import type { ReactNode } from "react";
import Link from "next/link";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

export type CockpitMetricTone = "critical" | "warn" | "ok" | "default";

export type CockpitMetric = {
  id: string;
  label: string;
  value: number | null;
  unavailableLabel: string;
  href?: string;
  tone: CockpitMetricTone;
  hint?: string;
};

export type CockpitActionLink = {
  href: string;
  label: string;
  hint?: string;
};

export type CockpitActionGroup = {
  id: string;
  title: string;
  hint?: string;
  links: readonly CockpitActionLink[];
};

export type CockpitFeedItem = {
  id: string;
  title: string;
  dossier: string;
  dueAt: string | null;
  owner: string;
  href: string;
  tone: "critical" | "high" | "default";
};

function formatMetric(value: number | null, unavailableLabel: string) {
  return value === null ? unavailableLabel : String(value);
}

export function CockpitHero({
  locale,
  eyebrow,
  title,
  lead,
  contextLine,
  statusLine,
  date,
  actions,
  aside,
}: {
  locale: Locale;
  eyebrow: string;
  title: string;
  lead: string;
  contextLine?: string | null;
  statusLine?: string | null;
  date: string;
  actions?: ReactNode;
  aside?: ReactNode;
}) {
  const dateLocale = locale === "ar" ? "ar-MA" : "fr-MA";
  return (
    <header className="admin-hero">
      <div className={`admin-hero-inner${aside ? "" : " !grid-cols-1"}`}>
        <div>
          <p className="admin-eyebrow">{eyebrow}</p>
          <h1>{title}</h1>
          <p className="admin-hero-lead">{lead}</p>
          <div className="cockpit-hero-meta">
            <time dateTime={date}>
              {new Intl.DateTimeFormat(dateLocale, { dateStyle: "full" }).format(new Date(date))}
            </time>
            {contextLine ? <span>{contextLine}</span> : null}
            {statusLine ? <span>{statusLine}</span> : null}
          </div>
          {actions ? <div className="admin-hero-actions">{actions}</div> : null}
        </div>
        {aside}
      </div>
    </header>
  );
}

export function CockpitMetricGrid({
  title,
  hint,
  metrics,
}: {
  title: string;
  hint?: string;
  metrics: readonly CockpitMetric[];
}) {
  return (
    <section className="space-y-4" aria-labelledby="cockpit-metrics-title">
      <div className="admin-section-head">
        <div>
          <h2 id="cockpit-metrics-title">{title}</h2>
          {hint ? <p>{hint}</p> : null}
        </div>
      </div>
      <div className="cockpit-metric-grid">
        {metrics.map((metric) => {
          const value = formatMetric(metric.value, metric.unavailableLabel);
          const body = (
            <>
              <p>{metric.label}</p>
              <strong dir="ltr">{value}</strong>
              {metric.hint ? <small>{metric.hint}</small> : null}
            </>
          );
          if (!metric.href || metric.value === null) {
            return (
              <div key={metric.id} className="cockpit-metric" data-tone={metric.tone} aria-disabled={metric.value === null ? "true" : undefined}>
                {body}
              </div>
            );
          }
          return (
            <Link key={metric.id} href={metric.href} className="cockpit-metric" data-tone={metric.tone}>
              {body}
            </Link>
          );
        })}
      </div>
    </section>
  );
}

export function CockpitActionGroups({
  title,
  groups,
}: {
  title: string;
  groups: readonly CockpitActionGroup[];
}) {
  return (
    <section className="space-y-4" aria-labelledby="cockpit-actions-title">
      <div className="admin-section-head">
        <h2 id="cockpit-actions-title">{title}</h2>
      </div>
      <div className="cockpit-action-groups">
        {groups.map((group) => (
          <article key={group.id} className="cockpit-action-group">
            <h3>{group.title}</h3>
            {group.hint ? <p>{group.hint}</p> : null}
            <ul className="admin-link-list">
              {group.links.map((link) => (
                <li key={`${group.id}:${link.href}:${link.label}`}>
                  <Link href={link.href} className="admin-link">
                    <span className="cockpit-action-tile" aria-hidden>
                      ↗
                    </span>
                    <span>
                      <strong>{link.label}</strong>
                      {link.hint ? <span>{link.hint}</span> : null}
                    </span>
                    <span className="cockpit-action-chevron" aria-hidden>→</span>
                  </Link>
                </li>
              ))}
            </ul>
          </article>
        ))}
      </div>
    </section>
  );
}

export function CockpitFeed({
  locale,
  title,
  hint,
  empty,
  error,
  openLabel,
  items,
  footer,
}: {
  locale: Locale;
  title: string;
  hint?: string;
  empty: string;
  error?: string | null;
  openLabel: string;
  items: readonly CockpitFeedItem[];
  footer?: ReactNode;
}) {
  const dateLocale = locale === "ar" ? "ar-MA" : "fr-MA";
  return (
    <section className="admin-panel space-y-4" aria-labelledby="cockpit-feed-title">
      <div className="admin-section-head">
        <div>
          <h2 id="cockpit-feed-title">{title}</h2>
          {hint ? <p>{hint}</p> : null}
        </div>
      </div>
      {error ? (
        <p role="alert" className="admin-notice">
          {error}
        </p>
      ) : items.length === 0 ? (
        <p role="status" className="text-sm text-[var(--ad-muted)]">
          {empty}
        </p>
      ) : (
        <div className="cockpit-feed">
          {items.map((item) => (
            <article key={item.id} className="cockpit-feed-item">
              <div>
                <span className="admin-badge" data-tone={item.tone}>
                  {item.title}
                </span>
                <p className="mt-2 font-semibold">{item.dossier}</p>
              </div>
              <p className="text-sm text-[var(--ad-muted)]">
                {item.dueAt
                  ? new Intl.DateTimeFormat(dateLocale, { dateStyle: "medium", timeStyle: "short" }).format(new Date(item.dueAt))
                  : "—"}
              </p>
              <p className="text-sm">{item.owner}</p>
              <Link href={item.href} className="admin-btn-outline !min-h-10 !px-3 !text-sm">
                {openLabel}
              </Link>
            </article>
          ))}
        </div>
      )}
      {footer}
    </section>
  );
}
