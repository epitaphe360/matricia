import { describe, expect, it } from "vitest";
import { getClientRecurringMessages } from "./messages";
describe("client recurring messages", () => { it("couvre FR et AR sans chaîne vide", () => { for (const locale of ["fr", "ar"] as const) { const messages = getClientRecurringMessages(locale); expect(Object.values(messages).flatMap((value) => typeof value === "string" ? [value] : Object.values(value)).every(Boolean)).toBe(true); } }); it("explique dans les deux langues que les cycles ne dépensent rien", () => { expect(getClientRecurringMessages("fr").safety).toContain("dépense"); expect(getClientRecurringMessages("ar").safety).toContain("إنفاق"); }); });

