import { describe, expect, it } from "vitest";
import { getMarketingMessages } from "./messages";

describe("marketing business labels", () => {
  it("localise exhaustivement les codes visibles en français", () => {
    const codes = getMarketingMessages("fr").codes;
    expect(Object.keys(codes.purposes)).toHaveLength(3);
    expect(Object.keys(codes.modes)).toHaveLength(3);
    expect(Object.keys(codes.channels)).toHaveLength(4);
    expect(Object.keys(codes.feedback)).toHaveLength(6);
    expect(codes.purposes.SOCIAL_PUBLISHING).toBe("Publication sur les réseaux sociaux");
    expect(codes.statuses.VALIDATED_BY_RULES).toBe("Validé par les règles");
  });
  it("fournit des libellés arabes distincts pour chaque famille", () => {
    const codes = getMarketingMessages("ar").codes;
    expect(codes.modes.ASSISTED).toBe("بمساعدة");
    expect(codes.providers.LINKEDIN).toBe("لينكدإن");
    expect(codes.channels.REEL).toBe("فيديو قصير");
    expect(codes.languages.FR).toBe("الفرنسية");
    expect(codes.feedback.PAUSE_CAMPAIGN).toBe("إيقاف الحملة مؤقتاً");
    expect(codes.feedback.REDUCE_FREQUENCY).toBe("خفض التواتر");
    expect(codes.feedback.CHANGE_SERVICE_FOCUS).toBe("تغيير الخدمة ذات الأولوية");
    expect(getMarketingMessages("ar").approveAssistedCalendar).toBe("الموافقة الشاملة على التقويم المساعد");
  });
});
