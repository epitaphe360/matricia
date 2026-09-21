import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { PlanningWeekBoard } from "./planning-board";

describe("PlanningWeekBoard", () => {
  it("place les échéances réelles sur le jour civil sans horaire inventé", () => {
    const html = renderToStaticMarkup(
      <PlanningWeekBoard
        locale="fr"
        today="2025-05-14"
        days={["2025-05-12", "2025-05-13", "2025-05-14", "2025-05-15", "2025-05-16", "2025-05-17", "2025-05-18"]}
        prevHref="/fr/sous-traitant/planning?week=2025-05-05"
        nextHref="/fr/sous-traitant/planning?week=2025-05-19"
        todayHref="/fr/sous-traitant/planning?week=2025-05-12"
        events={[{
          id: "invite:1",
          kind: "consultation",
          kindLabel: "Consultation",
          label: "Lot CVC",
          dueAt: "2025-05-14T11:00:00.000Z",
          href: "/fr/sous-traitant/consultations/1",
        }]}
      />,
    );
    expect(html).toContain("Lot CVC");
    expect(html).toContain("Consultation");
    expect(html).toContain("/fr/sous-traitant/consultations/1");
    expect(html).toContain("Afrique/Casablanca");
    expect(html).not.toMatch(/exemple illustratif/i);
  });
});
