import type { AdminVolumeDemand } from "@/modules/admin/data/catalog/model";
import { formatExactUnits } from "@/modules/shared/lib/volume-procurement/model";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getCommerceMessages } from "@/modules/admin/screens/finance/commerce-messages";

export function VolumeDemandPanel({ locale, demand }: { locale: Locale; demand: AdminVolumeDemand }) {
  const m = getCommerceMessages(locale);
  return (
    <section aria-labelledby="volume-demand" className="mt-8 space-y-4">
      <h2 id="volume-demand" className="text-xl font-semibold">{m.demand}</h2>
      <p className="text-sm text-muted-foreground">{m.demandHint}</p>
      {demand.default_reservation_ttl_hours ? <p dir="ltr">{m.ttlHours}: {demand.default_reservation_ttl_hours}</p> : null}
      <div className="grid gap-4 lg:grid-cols-2">
        <div>
          <h3 className="mb-2 font-semibold">{m.history}</h3>
          {demand.history.length === 0 ? <p>{m.empty}</p> : demand.history.map((item) => (
            <article key={`${item.month_start}-${item.sku_code}`} className="mb-2 rounded-xl border bg-card p-4 text-sm">
              <p className="font-semibold">{item.sku_code}</p>
              <p dir="ltr">{item.month_start} · {formatExactUnits(item.reserved_units, locale)} / {formatExactUnits(item.consumed_units, locale)} · {item.reservation_count}</p>
            </article>
          ))}
        </div>
        <div>
          <h3 className="mb-2 font-semibold">{m.demandForecast}</h3>
          {demand.forecasts.length === 0 ? <p>{m.empty}</p> : demand.forecasts.map((item) => (
            <article key={item.agreement_code} className="mb-2 rounded-xl border bg-card p-4 text-sm">
              <p className="font-semibold">{item.agreement_code} · {item.sku_code}</p>
              <p dir="ltr">{item.status} · {formatExactUnits(item.forecast_units, locale)} · {item.valid_from} → {item.valid_to}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
