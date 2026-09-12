import { describe, expect, it } from "vitest";
import { getSubscriptionMessages } from "./messages";

describe("subscription messages", () => {
  it("conserve les mêmes clés FR et AR", () => {
    expect(Object.keys(getSubscriptionMessages("ar")).sort()).toEqual(Object.keys(getSubscriptionMessages("fr")).sort());
  });
});
