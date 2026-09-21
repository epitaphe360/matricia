import { NextResponse } from "next/server";
import { loadAdminActorDirectory, memberLabel } from "@/modules/admin/data/spaces/actors-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export async function GET(request: Request, { params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  const directory = await loadAdminActorDirectory();
  const header = locale === "ar"
    ? ["المستخدم", "المؤسسة", "الأدوار", "الحالة"]
    : ["user", "organization", "roles", "status"];
  const lines = [
    header.join(","),
    ...directory.users.map((row) =>
      [memberLabel(locale, row.organizationName), row.organizationName, row.roles.join("|"), row.status]
        .map((value) => `"${String(value).replaceAll('"', '""')}"`)
        .join(","),
    ),
  ];
  return new NextResponse(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="utilisateurs-${locale}.csv"`,
    },
  });
}
