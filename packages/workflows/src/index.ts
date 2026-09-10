export type Transition<State extends string> = Readonly<{ from: State; to: State; event: string }>;
