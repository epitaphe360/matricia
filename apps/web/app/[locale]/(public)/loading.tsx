export default function PublicLoading() {
  return (
    <main className="min-h-[60dvh] px-4 py-16" aria-busy="true" aria-live="polite">
      <span className="sr-only">Chargement / جاري التحميل</span>
      <div className="mx-auto max-w-5xl space-y-8">
        <div className="h-12 w-64 animate-pulse rounded-lg bg-muted" />
        <div className="h-40 animate-pulse rounded-2xl bg-muted" />
        <div className="grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 4 }, (_, index) => <div key={index} className="h-28 animate-pulse rounded-xl bg-muted" />)}
        </div>
      </div>
    </main>
  );
}
