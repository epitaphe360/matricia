export type AssistanceActionState =
  | { status: "idle" }
  | { status: "success"; suggestionCount?: number }
  | { status: "error"; reason: "VALIDATION" | "UNAUTHENTICATED" | "FORBIDDEN" | "CONFLICT" | "FAILED" };

export const idleAssistanceAction: AssistanceActionState = { status: "idle" };
