const LOCAL_PATTERN = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/u;

function offsetMinutesAt(instant: number): number {
  const label = new Intl.DateTimeFormat("en-US", { timeZone: "Africa/Casablanca", timeZoneName: "longOffset" })
    .formatToParts(new Date(instant))
    .find((part) => part.type === "timeZoneName")?.value ?? "GMT";
  const match = /GMT([+-])(\d{2}):(\d{2})/u.exec(label);
  if (!match) return 0;
  const minutes = Number(match[2]) * 60 + Number(match[3]);
  return match[1] === "-" ? -minutes : minutes;
}

function formatOffset(minutes: number): string {
  const sign = minutes < 0 ? "-" : "+";
  const value = Math.abs(minutes);
  return `${sign}${String(Math.floor(value / 60)).padStart(2, "0")}:${String(value % 60).padStart(2, "0")}`;
}

/** Converts a `datetime-local` value entered as Moroccan wall-clock time into an ISO timestamp with its offset. */
export function casablancaLocalToIso(value: string): string | null {
  const match = LOCAL_PATTERN.exec(value.trim());
  if (!match) return null;
  const [, year, month, day, hour, minute] = match.map(Number) as [number, number, number, number, number, number];
  if (hour > 23 || minute > 59) return null;
  const naive = Date.UTC(year, month - 1, day, hour, minute);
  if (Number.isNaN(naive)) return null;
  const check = new Date(naive);
  if (check.getUTCFullYear() !== year || check.getUTCMonth() !== month - 1 || check.getUTCDate() !== day) return null;
  const offset = offsetMinutesAt(naive - offsetMinutesAt(naive) * 60000);
  return `${value.trim()}:00${formatOffset(offset)}`;
}
