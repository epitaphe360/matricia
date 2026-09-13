import { z } from "zod";

export const actionPriority = z.enum(["CRITICAL", "HIGH", "MEDIUM", "LOW"]);
export const actionKind = z.enum(["NOTIFICATION", "MESSAGE", "APPROVAL", "EXCEPTION", "RISK_REVIEW", "WORK_ITEM"]);

export type UserActionItem = {
  id: string;
  kind: z.infer<typeof actionKind>;
  title: string;
  detail: string;
  organizationName: string | null;
  priority: z.infer<typeof actionPriority>;
  mandatory: boolean;
  href: string;
  occurredAt: string;
  dueAt: string | null;
  requiresHumanReview: boolean;
};

export type UserActionCenter = {
  items: UserActionItem[];
  degradedSources: Array<"ADMIN">;
};

const rank: Record<UserActionItem["priority"], number> = { CRITICAL: 4, HIGH: 3, MEDIUM: 2, LOW: 1 };

export function orderUserActions(items: UserActionItem[], now: string): UserActionItem[] {
  const current = Date.parse(now);
  return [...items].sort((a, b) => {
    const aOverdue = a.dueAt !== null && Date.parse(a.dueAt) <= current ? 1 : 0;
    const bOverdue = b.dueAt !== null && Date.parse(b.dueAt) <= current ? 1 : 0;
    return Number(b.mandatory) - Number(a.mandatory)
      || bOverdue - aOverdue
      || rank[b.priority] - rank[a.priority]
      || Date.parse(a.dueAt ?? a.occurredAt) - Date.parse(b.dueAt ?? b.occurredAt);
  });
}

