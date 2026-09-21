export type QuoteCompletenessCheck = {
  key: "solution" | "deliverables" | "warranty" | "corrections" | "start" | "duration" | "validity" | "lines";
  present: boolean;
};

export type QuoteCompleteness = {
  basisPoints: number;
  checks: QuoteCompletenessCheck[];
};

const CHECKS: QuoteCompletenessCheck["key"][] = [
  "solution",
  "deliverables",
  "warranty",
  "corrections",
  "start",
  "duration",
  "validity",
  "lines",
];

export function quoteCompleteness(input: {
  solution: string;
  deliverablesCount: number;
  warranty: string;
  corrections: string;
  startDate: string;
  durationDays: number;
  validUntil: string;
  lineCount: number;
}): QuoteCompleteness {
  const present: Record<QuoteCompletenessCheck["key"], boolean> = {
    solution: input.solution.trim().length >= 3,
    deliverables: input.deliverablesCount > 0,
    warranty: input.warranty.trim().length >= 3,
    corrections: input.corrections.trim().length >= 3,
    start: /^\d{4}-\d{2}-\d{2}/u.test(input.startDate),
    duration: Number.isInteger(input.durationDays) && input.durationDays > 0,
    validity: input.validUntil.trim().length >= 10,
    lines: input.lineCount > 0,
  };
  const filled = CHECKS.filter((key) => present[key]).length;
  return {
    basisPoints: Math.trunc((filled * 10_000) / CHECKS.length),
    checks: CHECKS.map((key) => ({ key, present: present[key] })),
  };
}

export function formatCompletenessBasisPoints(basisPoints: number, locale: "fr" | "ar"): string {
  const whole = Math.trunc(Math.max(0, Math.min(10_000, basisPoints)) / 100);
  return locale === "ar" ? `${whole}٪` : `${whole} %`;
}
