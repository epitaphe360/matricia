import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import type { AdminVolumeDemand } from "@/modules/admin/data/catalog/model";
import { VolumeDemandPanel } from "./volume-demand-panel";

const demand: AdminVolumeDemand = {
  generated_at: "2026-09-21T12:00:00.000Z",
  default_reservation_ttl_hours: "168",
  history: [{ month_start: "2026-09-01", sku_code: "IT_HOUR", reserved_units: "12", consumed_units: "4", reservation_count: 2 }],
  forecasts: [{ agreement_code: "VOL_IT_2026", sku_code: "IT_HOUR", status: "ACTIVE", forecast_units: "100", valid_from: "2026-10-01", valid_to: "2026-12-31" }],
};

describe("VolumeDemandPanel", () => {
  it("affiche l’historique et le forecast négocié", () => {
    const html = renderToStaticMarkup(<VolumeDemandPanel locale="fr" demand={demand} />);
    expect(html).toContain("VOL_IT_2026");
    expect(html).toContain("IT_HOUR");
    expect(html).toContain("168");
    expect(html).not.toMatch(/\bTODO\b|\bFIXME\b/);
  });
});
