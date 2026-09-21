"use client";

import { Cell, Pie, PieChart, Bar, BarChart, XAxis, YAxis, CartesianGrid } from "recharts";
import { ChartContainer, ChartTooltip, ChartTooltipContent, type ChartConfig } from "@/modules/shared/ui/chart";

const palette = ["#053528", "#0a4a38", "#17643a", "#b7791f", "#a12828", "#e8d5b5", "#3d7a66"];

export function SupervisionCharts({
  requests,
  quotes,
  missions,
  labels,
}: {
  requests: Array<{ name: string; value: number }>;
  quotes: Array<{ name: string; value: number }>;
  missions: Array<{ name: string; value: number }>;
  labels: { requests: string; quotes: string; missions: string; empty: string };
}) {
  const requestConfig = Object.fromEntries(requests.map((item, index) => [item.name, { label: item.name, color: palette[index % palette.length] }])) satisfies ChartConfig;
  const quoteConfig = Object.fromEntries(quotes.map((item, index) => [item.name, { label: item.name, color: palette[(index + 2) % palette.length] }])) satisfies ChartConfig;
  const missionConfig = Object.fromEntries(missions.map((item, index) => [item.name, { label: item.name, color: palette[(index + 4) % palette.length] }])) satisfies ChartConfig;

  return (
    <div className="admin-chart-grid">
      <article className="admin-panel space-y-3">
        <h3 className="font-semibold">{labels.requests}</h3>
        {requests.length === 0 ? <p className="text-sm text-[var(--ad-muted)]">{labels.empty}</p> : (
          <ChartContainer config={requestConfig} className="aspect-square max-h-[240px]" initialDimension={{ width: 260, height: 220 }}>
            <PieChart>
              <ChartTooltip content={<ChartTooltipContent nameKey="name" />} />
              <Pie data={requests} dataKey="value" nameKey="name" innerRadius={46} outerRadius={78} paddingAngle={3}>
                {requests.map((entry, index) => <Cell key={entry.name} fill={palette[index % palette.length]} />)}
              </Pie>
            </PieChart>
          </ChartContainer>
        )}
      </article>
      <article className="admin-panel space-y-3">
        <h3 className="font-semibold">{labels.quotes}</h3>
        {quotes.length === 0 ? <p className="text-sm text-[var(--ad-muted)]">{labels.empty}</p> : (
          <ChartContainer config={quoteConfig} className="aspect-[4/3] max-h-[240px]" initialDimension={{ width: 280, height: 220 }}>
            <BarChart data={quotes}>
              <CartesianGrid vertical={false} stroke="#d7e3dc" />
              <XAxis dataKey="name" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "#5a6f66" }} />
              <YAxis allowDecimals={false} tickLine={false} axisLine={false} width={28} />
              <ChartTooltip content={<ChartTooltipContent nameKey="name" />} />
              <Bar dataKey="value" radius={[8, 8, 0, 0]}>
                {quotes.map((entry, index) => <Cell key={entry.name} fill={palette[(index + 2) % palette.length]} />)}
              </Bar>
            </BarChart>
          </ChartContainer>
        )}
      </article>
      <article className="admin-panel space-y-3">
        <h3 className="font-semibold">{labels.missions}</h3>
        {missions.length === 0 ? <p className="text-sm text-[var(--ad-muted)]">{labels.empty}</p> : (
          <ChartContainer config={missionConfig} className="aspect-[4/3] max-h-[240px]" initialDimension={{ width: 280, height: 220 }}>
            <BarChart data={missions} layout="vertical" margin={{ left: 8, right: 8 }}>
              <CartesianGrid horizontal={false} stroke="#d7e3dc" />
              <XAxis type="number" hide />
              <YAxis type="category" dataKey="name" width={90} tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: "#5a6f66" }} />
              <ChartTooltip content={<ChartTooltipContent nameKey="name" />} />
              <Bar dataKey="value" radius={[0, 8, 8, 0]}>
                {missions.map((entry, index) => <Cell key={entry.name} fill={palette[(index + 4) % palette.length]} />)}
              </Bar>
            </BarChart>
          </ChartContainer>
        )}
      </article>
    </div>
  );
}
