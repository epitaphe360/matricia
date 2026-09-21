"use client";

import { useActionState, useId } from "react";
import { libraryCopy } from "@/modules/franchise/data/library/copy";
import type { FranchiseLibraryWorkspace } from "@/modules/franchise/data/library/workspace";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { simulateFranchiseQuestionnaireAction, type FranchiseSimulationActionState } from "./actions";

const initial: FranchiseSimulationActionState = { status: "idle" };

export function FranchiseQuestionnaireSandbox({
  locale,
  workspace,
  organizationId,
  selectedQuestionnaireId,
}: {
  locale: Locale;
  workspace: FranchiseLibraryWorkspace;
  organizationId: string | null;
  selectedQuestionnaireId: string | null;
}) {
  const c = libraryCopy(locale);
  const prefix = useId();
  const [state, action, pending] = useActionState(simulateFranchiseQuestionnaireAction, initial);
  const selected = workspace.questionnaires.find((item) => item.id === selectedQuestionnaireId) ?? workspace.questionnaires[0] ?? null;
  const questions = workspace.questions.filter((item) => !selected || item.questionnaireId === selected.id || item.questionnaireId === null);
  const error = state.status === "error"
    ? state.reason === "FORBIDDEN" ? c.forbidden : state.reason === "VALIDATION" ? (locale === "ar" ? "تحققوا من الحقول." : "Complétez la simulation.") : c.unavailable
    : null;
  if (!selected?.questionnaireVersionId) return <p className="client-access-note">{c.simulationPending}</p>;
  return (
    <form action={action} className="franchise-props-form">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="libraryId" value={workspace.mandate.libraryId} />
      {organizationId ? <input type="hidden" name="organizationId" value={organizationId} /> : null}
      <input type="hidden" name="questionnaireId" value={selected.id} />
      <input type="hidden" name="questionnaireVersionId" value={selected.questionnaireVersionId} />
      <label className="franchise-field">{c.answerQuestion}
        <select id={`${prefix}-question`} name="questionVersionId" defaultValue={questions[0]?.versionId ?? ""}>
          {(questions.length ? questions : [{ id: "empty", versionId: "", label: "—", key: "" }]).map((item) => (
            <option key={item.id} value={item.versionId ?? ""}>{item.label || item.key}</option>
          ))}
        </select>
      </label>
      <label className="franchise-field">{c.exampleAnswers}
        <input name="answer" defaultValue="true" className="min-h-11 w-full rounded-md border px-3" />
      </label>
      <button type="submit" className="franchise-tool franchise-tool-primary" disabled={pending}>{c.runSimulation}</button>
      <p role={error ? "alert" : "status"} aria-live="polite">
        {error ?? (state.status === "success" ? `${c.questionnaireSimulated} (${state.detail})` : c.sandboxHelp)}
      </p>
    </form>
  );
}
