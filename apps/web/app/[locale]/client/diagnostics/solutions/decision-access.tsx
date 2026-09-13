import type { SolutionLevel } from "@/lib/solution-insights/model";
import { DecisionForm } from "./decision-form";
import type { Messages } from "./messages";

export function SolutionDecisionAccess({
  canDecide,
  locale,
  solutionSetId,
  level,
  idempotencyKey,
  messages,
}: {
  canDecide: boolean;
  locale: "fr" | "ar";
  solutionSetId: string;
  level: SolutionLevel;
  idempotencyKey: string;
  messages: Messages;
}) {
  if (!canDecide) {
    return <p role="status" className="mt-4 rounded-md border bg-muted/40 p-3 text-sm text-muted-foreground">{messages.readOnly}</p>;
  }
  return <DecisionForm locale={locale} solutionSetId={solutionSetId} level={level} idempotencyKey={idempotencyKey} m={messages} />;
}
