import { NextResponse } from "next/server";
import { isAdminSpaceId } from "@/modules/admin/data/spaces/admin-nav";
import { spaceSpec } from "@/modules/admin/data/spaces/screen-catalog";
import { loadAdminSpaceSnapshot } from "@/modules/admin/data/spaces/space-data";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export async function GET(_request: Request, { params }: { params: Promise<{ locale: string; space: string }> }) {
  const { locale, space } = await params;
  if (!isLocale(locale) || !isAdminSpaceId(space)) return NextResponse.json({ error: "NOT_FOUND" }, { status: 404 });
  const snapshot = await loadAdminSpaceSnapshot(locale, space, "");
  if (snapshot.reason === "FORBIDDEN") return NextResponse.json({ error: "FORBIDDEN" }, { status: 403 });
  const spec = spaceSpec(space);
  const header = spec.columns(locale);
  const lines = [
    ["id", ...header].join(","),
    ...snapshot.rows.map((row) =>
      [row.id, ...row.cells].map((value) => `"${String(value).replaceAll('"', '""')}"`).join(","),
    ),
  ];
  return new NextResponse(lines.join("\n"), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${space}-${locale}.csv"`,
    },
  });
}
