export type CommandContext = Readonly<{ actorId: string; organizationId: string; correlationId: string; idempotencyKey?: string }>;
