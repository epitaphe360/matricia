"use client";

import { Cell, Pie, PieChart, Bar, BarChart, XAxis, YAxis, CartesianGrid } from "recharts";
import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/modules/shared/ui/chart";
import type { DashboardActionSummary } from "@/modules/shared/lib/action-center/dashboard-summary";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

type TrackingCopy = {
  scoreTitle: string;
  scoreHint: string;
  priorityTitle: string;
  kindTitle: string;
  emptyChart: string;
  priority: Record<"CRITICAL" | "HIGH" | "MEDIUM" | "LOW", string>;
  kind: Record<"NOTIFICATION" | "MESSAGE" | "APPROVAL" | "EXCEPTION" | "RISK_REVIEW" | "WORK_ITEM", string>;
};

const priorityColors = {
  CRITICAL: "#a12828",
  HIGH: "#b7791f",
  MEDIUM: "#1d6b54",
  LOW: "#8aa396",
} as const;

const kindColors = {
  APPROVAL: "#053528",
  EXCEPTION: "#a12828",
  RISK_REVIEW: "#b7791f",
  WORK_ITEM: "#0a4a38",
  NOTIFICATION: "#3d7a66",
  MESSAGE: "#e8d5b5",
} as const;

export function DashboardTrackingCharts({
  summary,
  locale,
  copy,
}: {
  summary: DashboardActionSummary;
  locale: Locale;
  copy: TrackingCopy;
}) {
  const priorityData = (["CRITICAL", "HIGH", "MEDIUM", "LOW"] as const)
    .map((key) => ({ key, name: copy.priority[key], value: summary.byPriority[key], fill: priorityColors[key] }))
    .filter((entry) => entry.value > 0);

  const kindData = (["APPROVAL", "EXCEPTION", "RISK_REVIEW", "WORK_ITEM", "NOTIFICATION", "MESSAGE"] as const)
    .map((key) => ({ key, name: copy.kind[key], value: summary.byKind[key], fill: kindColors[key] }))
    .filter((entry) => entry.value > 0);

  const priorityConfig = Object.fromEntries(priorityData.map((entry) => [entry.key, { label: entry.name, color: entry.fill }])) satisfies ChartConfig;
  const kindConfig = Object.fromEntries(kindData.map((entry) => [entry.key, { label: entry.name, color: entry.fill }])) satisfies ChartConfig;

  const scoreTone = summary.followUpScore >= 75 ? "ok" : summary.followUpScore >= 45 ? "warn" : "critical";
  const scoreColor = scoreTone === "ok" ? "#17643a" : scoreTone === "warn" ? "#b7791f" : "#a12828";
  const scoreRing = [
    { name: "score", value: summary.followUpScore, fill: scoreColor },
    { name: "rest", value: Math.max(0, 100 - summary.followUpScore), fill: "#e5efe9" },
  ];

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)_minmax(0,1.1fr)]" dir={locale === "ar" ? "rtl" : "ltr"}>
      <article className="admin-panel flex flex-col items-center justify-center gap-3 text-center">
        <h3 className="text-sm font-semibold text-[var(--ad-muted)]">{copy.scoreTitle}</h3>
        <div className="relative w-full max-w-[220px]">
          <ChartContainer config={{ score: { label: copy.scoreTitle, color: scoreColor } }} className="aspect-square max-h-[220px]" initialDimension={{ width: 220, height: 220 }}>
            <PieChart>
              <Pie data={scoreRing} dataKey="value" nameKey="name" innerRadius={68} outerRadius={92} strokeWidth={0} startAngle={90} endAngle={-270}>
                {scoreRing.map((entry) => (
                  <Cell key={entry.name} fill={entry.fill} />
                ))}
              </Pie>
            </PieChart>
          </ChartContainer>
          <div className="pointer-events-none absolute inset-0 grid place-items-center">
            <div>
              <p className="text-4xl font-bold tracking-tight" style={{ color: scoreColor }} dir="ltr">
                {summary.followUpScore}
              </p>
              <p className="text-xs font-semibold text-[var(--ad-muted)]">/ 100</p>
            </div>
          </div>
        </div>
        <p className="max-w-[16rem] text-sm leading-6 text-[var(--ad-muted)]">{copy.scoreHint}</p>
      </article>

      <article className="admin-panel space-y-3">
        <h3 className="text-sm font-semibold text-[var(--ad-ink)]">{copy.priorityTitle}</h3>
        {priorityData.length === 0 ? (
          <p className="text-sm text-[var(--ad-muted)]">{copy.emptyChart}</p>
        ) : (
          <ChartContainer config={priorityConfig} className="aspect-[4/3] max-h-[240px]" initialDimension={{ width: 320, height: 220 }}>
            <PieChart>
              <ChartTooltip content={<ChartTooltipContent nameKey="name" />} />
              <Pie data={priorityData} dataKey="value" nameKey="name" innerRadius={48} outerRadius={78} paddingAngle={3}>
                {priorityData.map((entry) => (
                  <Cell key={entry.key} fill={entry.fill} />
                ))}
              </Pie>
            </PieChart>
          </ChartContainer>
        )}
        <ul className="grid gap-2 sm:grid-cols-2">
          {(["CRITICAL", "HIGH", "MEDIUM", "LOW"] as const).map((key) => (
            <li key={key} className="flex items-center justify-between gap-2 rounded-xl border border-[var(--ad-border)] bg-[#fbfdfc] px-3 py-2 text-sm">
              <span className="inline-flex items-center gap-2">
                <span className="size-2.5 rounded-full" style={{ background: priorityColors[key] }} aria-hidden />
                {copy.priority[key]}
              </span>
              <strong dir="ltr">{summary.byPriority[key]}</strong>
            </li>
          ))}
        </ul>
      </article>

      <article className="admin-panel space-y-3">
        <h3 className="text-sm font-semibold text-[var(--ad-ink)]">{copy.kindTitle}</h3>
        {kindData.length === 0 ? (
          <p className="text-sm text-[var(--ad-muted)]">{copy.emptyChart}</p>
        ) : (
          <ChartContainer config={kindConfig} className="aspect-[4/3] max-h-[240px]" initialDimension={{ width: 320, height: 220 }}>
            <BarChart data={kindData} layout="vertical" margin={{ left: 8, right: 8, top: 8, bottom: 8 }}>
              <CartesianGrid horizontal={false} stroke="#d7e3dc" />
              <XAxis type="number" hide />
              <YAxis type="category" dataKey="name" width={88} tickLine={false} axisLine={false} tick={{ fill: "#5a6f66", fontSize: 11 }} />
              <ChartTooltip content={<ChartTooltipContent nameKey="name" />} />
              <Bar dataKey="value" radius={[0, 8, 8, 0]}>
                {kindData.map((entry) => (
                  <Cell key={entry.key} fill={entry.fill} />
                ))}
              </Bar>
            </BarChart>
          </ChartContainer>
        )}
      </article>
    </div>
  );
}
