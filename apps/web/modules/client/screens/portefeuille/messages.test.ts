import { describe, expect, it } from "vitest";
import { getMessages } from "./messages";

describe("portefeuille messages", () => {
  it("keeps the same keys in French and Arabic", () => {
    expect(Object.keys(getMessages("ar")).sort()).toEqual(Object.keys(getMessages("fr")).sort());
  });

  it("localizes consumption alerts", () => {
    expect(getMessages("ar").alerts.watch).not.toBe(getMessages("fr").alerts.watch);
    expect(getMessages("fr").alerts.exceeded).toContain("dépassé");
  });
});
