import { describe, expect, it } from "vitest";
import { moduleHubCopy } from "./module-hub-copy";

describe("module hub", () => {
  it("expose les mêmes routes en français et en arabe", () => {
    expect(moduleHubCopy.ar.links.map(([, route]) => route)).toEqual(moduleHubCopy.fr.links.map(([, route]) => route));
  });

  it("n’expose aucune route dupliquée", () => {
    const routes = moduleHubCopy.fr.links.map(([, route]) => route);
    expect(new Set(routes).size).toBe(routes.length);
  });
});
