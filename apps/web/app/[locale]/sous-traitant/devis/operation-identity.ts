export type RevisionIdentity = { revision: string; correlation: string };
export type SubmitIdentity = { submit: string; correlation: string };

export function rotateRevisionIdentity(makeUuid: () => string = () => crypto.randomUUID()): RevisionIdentity {
  return { revision:makeUuid(), correlation:makeUuid() };
}

export function rotateSubmitIdentity(makeUuid: () => string = () => crypto.randomUUID()): SubmitIdentity {
  return { submit:makeUuid(), correlation:makeUuid() };
}
