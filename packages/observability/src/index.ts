export type SafeLogContext = Readonly<{ correlationId: string; event: string; outcome: "success" | "failure" }>;
