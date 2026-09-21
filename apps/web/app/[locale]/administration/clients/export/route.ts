import { NextResponse } from "next/server";
import { loadAdminClientDirectory } from "@/modules/admin/data/spaces/actors-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export async function GET(_request: Request, { params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  const directory = await loadAdminClientDirectory(locale);
  if (directory.reason === "UNAUTHENTICATED") {
    return NextResponse.redirect(new URL(`/${locale}/connexion`, _request.url));
  }
  const header = locale === "ar"
    ? ["المعرف", "الاسم", "الاسم القانوني", "الحالة", "الطلبات", "النزاعات"]
    : ["id", "display_name", "legal_name", "status", "open_requests", "open_disputes"];
  const lines = [
    header.join(","),
    ...directory.organizations.map((org) =>
      [org.id, org.display_name, org.legal_name, org.status, org.open_requests, org.open_disputes]
        .map((value) => `"${String(value).replaceAll('"', '""')}"`)
        .join(","),
    ),
  ];
  return new NextResponse(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="clients-${locale}.csv"`,
    },
  });
}
