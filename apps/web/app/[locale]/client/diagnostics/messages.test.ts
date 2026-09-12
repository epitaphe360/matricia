import{describe,expect,it}from"vitest";import{messages}from"./messages";describe("diagnostics translations",()=>{it("contains bilingual workflow labels",()=>{expect(messages("fr").title).not.toBe(messages("ar").title);expect(Object.keys(messages("ar").statuses)).toHaveLength(5)})});

