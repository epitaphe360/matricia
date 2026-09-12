import { getRuleValidationMessages } from "./messages";

export default function RuleValidationLoading() {
  const label = `${getRuleValidationMessages("fr").processing} / ${getRuleValidationMessages("ar").processing}`;
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8"><div className="mx-auto max-w-7xl space-y-6" role="status" aria-live="polite" aria-busy="true" aria-label={label}><div className="h-10 w-2/3 animate-pulse rounded-md bg-muted" aria-hidden="true"/><div className="grid gap-5 xl:grid-cols-2" aria-hidden="true"><div className="h-72 animate-pulse rounded-xl border bg-background"/><div className="h-72 animate-pulse rounded-xl border bg-background"/></div><div className="h-48 animate-pulse rounded-xl border bg-background" aria-hidden="true"/></div></main>;
}
