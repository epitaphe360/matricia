import type { AdminSupervisionDashboard } from "./types";

export function supervisionChartSeries(dashboard: AdminSupervisionDashboard) {
  const requestByStatus = new Map<string, number>();
  for (const item of dashboard.requests) requestByStatus.set(item.status, (requestByStatus.get(item.status) ?? 0) + 1);
  const missionByStatus = new Map<string, number>();
  for (const item of dashboard.missions) missionByStatus.set(item.status, (missionByStatus.get(item.status) ?? 0) + 1);
  const quoteByStatus = new Map<string, number>();
  for (const item of dashboard.quotes) quoteByStatus.set(item.status, (quoteByStatus.get(item.status) ?? 0) + 1);
  return {
    requests: [...requestByStatus.entries()].map(([name, value]) => ({ name, value })),
    missions: [...missionByStatus.entries()].map(([name, value]) => ({ name, value })),
    quotes: [...quoteByStatus.entries()].map(([name, value]) => ({ name, value })),
    totals: {
      organizations: dashboard.organizations.length,
      requests: dashboard.requests.length,
      quotes: dashboard.quotes.length,
      missions: dashboard.missions.length,
      diagnostics: dashboard.diagnostics.length,
      blocked: dashboard.organizations.reduce((sum, org) => sum + org.open_disputes, 0),
    },
  };
}
