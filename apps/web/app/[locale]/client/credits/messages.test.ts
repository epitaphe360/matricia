import{describe,expect,it}from"vitest";import{messages}from"./messages";describe("credit translations",()=>{it("ships FR and AR wallet workflows",()=>{expect(messages("fr").title).not.toBe(messages("ar").title);expect(Object.keys(messages("ar").statuses)).toHaveLength(8)})});

