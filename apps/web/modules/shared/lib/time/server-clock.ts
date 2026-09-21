import "server-only";

export function getServerTimestamp(): number {
  return Date.now();
}
