import { describe, expect, it } from "vitest";
import { getAssistanceMessages } from "./messages";

describe("assistance messages", () => {
  it("couvre les mêmes clés en français et en arabe", () => {
    expect(Object.keys(getAssistanceMessages("ar"))).toEqual(Object.keys(getAssistanceMessages("fr")));
    expect(Object.keys(getAssistanceMessages("ar").contexts)).toEqual(Object.keys(getAssistanceMessages("fr").contexts));
  });
});
