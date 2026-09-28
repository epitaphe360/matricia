import { renderToStaticMarkup } from "react-dom/server";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { formatMinor } from "@/modules/shared/lib/subscriptions/model";

const loadPublicSubscriptionPlans = vi.fn();

vi.mock("next/navigation", () => ({ notFound: vi.fn(() => { throw new Error("NOT_FOUND"); }) }));
vi.mock("@/modules/public/ui/site/public-photo", () => ({ PublicPhoto: () => <div>photo</div> }));
vi.mock("@/modules/public/data/subscriptions/repository", () => ({ loadPublicSubscriptionPlans: () => loadPublicSubscriptionPlans() }));

import PublicSubscriptionsPage from "./page";

const premium = {
  id: "11111111-1111-4111-8111-111111111111",
  code: "PREMIUM" as const,
  currency: "MAD",
  monthlyPriceMinor: "10000",
  annualPriceMinor: "100000",
  monthlyCreditGrant: "20",
};
const gold = {
  ...premium,
  id: "22222222-2222-4222-8222-222222222222",
  code: "GOLD" as const,
  monthlyPriceMinor: "25000",
  annualPriceMinor: "250000",
  monthlyCreditGrant: "80",
};

describe("page publique abonnements", () => {
  beforeEach(() => loadPublicSubscriptionPlans.mockReset());

  it("distingue les plans par le prix et les crédits réels, sans liste identique", async () => {
    loadPublicSubscriptionPlans.mockResolvedValue({ status: "success", plans: [premium, gold] });
    const html = renderToStaticMarkup(await PublicSubscriptionsPage({ params: Promise.resolve({ locale: "fr" }) }));
    expect(html).toContain(formatMinor(premium.monthlyPriceMinor, "MAD", "fr"));
    expect(html).toContain(formatMinor(gold.monthlyPriceMinor, "MAD", "fr"));
    expect(html).toContain(">20<");
    expect(html).toContain(">80<");
    expect(html).toContain("is-featured");
    expect(html).not.toContain("Essentiel");
    expect(html).not.toContain("Organisation");
    expect(html).toContain("ne finance pas les honoraires");
  });

  it("n’invente pas trois cartes quand les plans publics sont indisponibles", async () => {
    loadPublicSubscriptionPlans.mockResolvedValue({ status: "unavailable" });
    const html = renderToStaticMarkup(await PublicSubscriptionsPage({ params: Promise.resolve({ locale: "fr" }) }));
    expect(html).toContain("confirmées avant souscription");
    expect(html).not.toContain("Essentiel");
    expect(html).not.toContain("Premium");
    expect(html).not.toContain("Organisation");
  });

  it("affiche le tarif à confirmer quand le prix publié est nul", async () => {
    loadPublicSubscriptionPlans.mockResolvedValue({ status: "success", plans: [{ ...premium, monthlyPriceMinor: "0", annualPriceMinor: "0" }] });
    const html = renderToStaticMarkup(await PublicSubscriptionsPage({ params: Promise.resolve({ locale: "fr" }) }));
    expect(html).toContain("Tarif communiqué avant souscription");
    expect(html).not.toContain(formatMinor("0", "MAD", "fr"));
  });
});
