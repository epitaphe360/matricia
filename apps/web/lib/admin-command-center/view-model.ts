import type { AdminWorkItem } from "./model";

export type AdminWorkSummary = { ordered: AdminWorkItem[]; critical: number; overdue: number; dueToday: number; humanReview: number; exceptions: number };
const priorityRank: Record<AdminWorkItem["priority"], number> = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };
function dayInMorocco(value: string | Date) { return new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Casablanca", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(value)) }
export function summarizeAdminWork(items: AdminWorkItem[], currentTime: string): AdminWorkSummary {
  const now = new Date(currentTime).getTime(), today = dayInMorocco(currentTime);
  const ordered = [...items].sort((left, right) => Number(dayInMorocco(left.dueAt) !== today) - Number(dayInMorocco(right.dueAt) !== today) || priorityRank[left.priority] - priorityRank[right.priority] || new Date(left.dueAt).getTime() - new Date(right.dueAt).getTime());
  return { ordered, critical: items.filter(item => item.priority === "CRITICAL").length, overdue: items.filter(item => new Date(item.dueAt).getTime() < now).length, dueToday: items.filter(item => dayInMorocco(item.dueAt) === today).length, humanReview: items.filter(item => item.sourceKind === "RISK_FLAG" || item.sourceKind === "MANUAL_REVIEW").length, exceptions: items.filter(item => item.sourceKind === "EXCEPTION").length };
}
