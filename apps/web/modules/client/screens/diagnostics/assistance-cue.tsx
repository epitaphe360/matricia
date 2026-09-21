import Link from "next/link";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getAssistanceMessages } from "./assistance/messages";

export function AssistanceCue({
  locale,
  href,
  proposedCount = 0,
  reassessmentCount = 0,
  context,
}: {
  locale: Locale;
  href: string;
  proposedCount?: number;
  reassessmentCount?: number;
  context: "diagnostic" | "quotes" | "milestone" | "need";
}) {
  const m = getAssistanceMessages(locale);
  const lead = context === "quotes" ? m.cueQuotes : context === "milestone" ? m.cueMilestone : context === "need" ? m.cueNeed : m.cueDiagnostic;
  return (
    <aside className="client-assistance-cue" aria-label={m.cueTitle}>
      <p className="client-assistance-cue-title">{m.cueTitle}</p>
      <p>{lead}</p>
      <p role="status">{m.safety}</p>
      {proposedCount > 0 ? (
        <p>
          <bdi dir="ltr">{proposedCount}</bdi> {m.cueProposed}
        </p>
      ) : null}
      {reassessmentCount > 0 ? (
        <p>
          <bdi dir="ltr">{reassessmentCount}</bdi> {m.cueReassessment}
        </p>
      ) : null}
      <Link href={href} className="client-ghost-link">{m.cueOpen}</Link>
    </aside>
  );
}
