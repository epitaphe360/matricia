import { describe, expect, it } from "vitest";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AdminProcessStrip } from "./admin-process-strip";

describe("AdminProcessStrip", () => {
  it("expose état, responsable et prochaine action", () => {
    const html = renderToStaticMarkup(
      createElement(AdminProcessStrip, {
        locale: "fr",
        title: "Cycle",
        owner: "Admin",
        nextAction: "Traiter",
        blocker: "Litige ouvert",
        steps: [
          { id: "a", label: "Scan", state: "done" },
          { id: "b", label: "Décision", state: "current" },
        ],
      }),
    );
    expect(html).toContain("Responsable");
    expect(html).toContain("Prochaine action");
    expect(html).toContain("Litige ouvert");
    expect(html).toContain('data-state="current"');
  });
});
