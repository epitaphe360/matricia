import { describe, expect, it } from "vitest";
import { rotateRevisionIdentity, rotateSubmitIdentity } from "./operation-identity";

describe("quote operation identity lifecycle", () => {
  it("keeps one identity for retries and rotates only after a confirmed revision", () => {
    const first = { revision:"first-operation", correlation:"first-correlation" };
    const replay = first;
    expect(replay).toEqual(first);
    const values = ["second-operation", "second-correlation"];
    const second = rotateRevisionIdentity(() => values.shift()!);
    expect(second).toEqual({ revision:"second-operation", correlation:"second-correlation" });
    expect(second).not.toEqual(first);
  });

  it("rotates submission identity after confirmed success", () => {
    const values = ["next-submit", "next-correlation"];
    expect(rotateSubmitIdentity(() => values.shift()!)).toEqual({ submit:"next-submit", correlation:"next-correlation" });
  });
});
