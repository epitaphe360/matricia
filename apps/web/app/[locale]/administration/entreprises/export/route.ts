import { NextResponse } from "next/server";
import { loadAdminSupervisionDashboard } from "@/modules/admin/data/supervision/repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export async function GET(_request: Request, { params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  const result = await loadAdminSupervisionDashboard(200);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") {
    return NextResponse.redirect(new URL(`/${locale}/connexion`, _request.url));
  }
  if (result.status === "error") {
    return NextResponse.json({ error: result.reason }, { status: result.reason === "FORBIDDEN" ? 403 : 503 });
  }
  const header = locale === "ar"
    ? ["المعرف", "الاسم", "الاسم القانوني", "الحالة", "الأعضاء", "الطلبات", "النزاعات"]
    : ["id", "display_name", "legal_name", "status", "member_count", "open_requests", "open_disputes"];
  const lines = [
    header.join(","),
    ...result.value.organizations.map((org) =>
      [org.id, org.display_name, org.legal_name, org.status, org.member_count, org.open_requests, org.open_disputes]
        .map((value) => `"${String(value).replaceAll('"', '""')}"`)
        .join(","),
    ),
  ];
  return new NextResponse(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="organisations-${locale}.csv"`,
    },
  });
}
