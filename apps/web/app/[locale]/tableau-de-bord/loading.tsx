export default function DashboardLoading() {
  return (
    <main className="min-h-dvh px-4 py-6 sm:px-6 sm:py-8" aria-busy="true" aria-live="polite">
      <span className="sr-only">Chargement du tableau de bord / جاري تحميل لوحة القيادة</span>
      <div className="mx-auto max-w-6xl space-y-6">
        <div className="h-24 animate-pulse rounded-2xl bg-muted" />
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }, (_, index) => <div key={index} className="h-24 animate-pulse rounded-xl bg-muted" />)}
        </div>
        <div className="h-64 animate-pulse rounded-2xl bg-muted" />
      </div>
    </main>
  );
}
