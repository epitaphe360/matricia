import { describe, expect, it } from "vitest";
import { displayCalendarDate, exactMoney, moneyToMinor, type CalendarItem } from "./model";

describe("client portfolio exact money", () => {
  it.each([
    ["0", "MAD", "0.00 MAD"],
    ["125005", "MAD", "1250.05 MAD"],
    ["900719925474099312345", "MAD", "9007199254740993123.45 MAD"],
  ])("formats %s without floating point", (minor, currency, expected) => expect(exactMoney(minor, currency)).toBe(expected));

  it.each([["1250", "125000"], ["1250,5", "125050"], ["1250.05", "125005"]])("parses %s exactly", (input, expected) => expect(moneyToMinor(input)).toBe(expected));
  it.each(["-1", "1.001", "NaN", "1e3", "", "12,345"])("rejects malformed amount %s", input => expect(moneyToMinor(input)).toBeNull());
});

describe("client portfolio calendar dates", () => {
  const item: CalendarItem = { organizationId:"00000000-0000-4000-8000-000000000001",projectId:null,itemId:"00000000-0000-4000-8000-000000000002",sourceKind:"DOCUMENT_EXPIRY",eventType:"DOCUMENT",titleFr:"Expiration",titleAr:"انتهاء",startsAt:"2026-12-31T00:00:00Z",endsAt:null,status:"VERIFIED",occursOn:"2026-12-31",allDay:true };
  it("preserves an all-day business date without browser timezone drift", () => expect(displayCalendarDate(item,"fr")).toContain("31 décembre 2026"));
  it("formats timestamps in the Morocco business timezone", () => expect(displayCalendarDate({...item,allDay:false,occursOn:null,startsAt:"2026-12-15T14:30:00Z"},"fr")).toContain("15:30"));
});
