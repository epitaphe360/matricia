import { describe, expect, it } from "vitest";
import { formatVersionMessage, getClientOnboardingMessages } from "./messages";

function collectFunctions(value: unknown, path = "messages"): string[] {
  if (typeof value === "function") return [path];
  if (value === null || typeof value !== "object") return [];
  return Object.entries(value).flatMap(([key, child]) => collectFunctions(child, `${path}.${key}`));
}

describe("messages sérialisables de l’onboarding Client", () => {
  it.each(["fr", "ar"] as const)("ne transmet aucune fonction au Client Component en %s", (locale) => {
    const messages = getClientOnboardingMessages(locale);
    expect(collectFunctions(messages)).toEqual([]);
    expect(() => structuredClone(messages)).not.toThrow();
    expect(() => JSON.stringify(messages)).not.toThrow();
  });

  it("insère la version dans les retours français et arabes", () => {
    const fr = getClientOnboardingMessages("fr");
    const ar = getClientOnboardingMessages("ar");
    expect(formatVersionMessage(fr.saved, 7)).toContain("Version 7");
    expect(formatVersionMessage(fr.documentUploaded, 3)).toContain("version 3");
    expect(formatVersionMessage(ar.questionResponseVersion, 4)).toContain("4");
    expect(formatVersionMessage(ar.questionAnswered, 9)).toContain("9");
  });
});
