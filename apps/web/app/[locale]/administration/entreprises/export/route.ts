import { loadMyPlatformAccess, hasPlatformRole } from "@/modules/shared/lib/account-security/platform-access";
import { loadAdminSupervisionDashboard } from "@/modules/admin/data/supervision/repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

const exportRoles = ["SUPER_ADMIN", "MATRICIA_ADMIN", "COMPLIANCE_MANAGER", "FINANCE_MANAGER", "DISPUTE_MANAGER", "LIBRARY_MANAGER", "READ_ONLY_AUDITOR"] as const;

function cell(value: string | number) {
  const text = String(value);
  return /[",\n\r]/u.test(text) ? `"${text.replaceAll("\"", "\"\"")}"` : text;
}

export async function GET(request: Request, context: { params: Promise<{ locale: string }> }) {
  const { locale } = await context.params;
  if (!isLocale(locale)) return new Response(null, { status: 404 });
  const access = await loadMyPlatformAccess();
  if (access.status === "error") return new Response(null, { status: access.reason === "UNAUTHENTICATED" ? 401 : 403 });
  if (!hasPlatformRole(access.roles, exportRoles)) return new Response(null, { status: 403 });
  const result = await loadAdminSupervisionDashboard(500);
  if (result.status !== "success") return new Response(null, { status: result.reason === "FORBIDDEN" ? 403 : 503 });
  const header = ["id", "display_name", "legal_name", "status", "created_at", "member_count", "open_requests", "open_disputes"];
  const lines = result.value.organizations.map((org) => [
    org.id,
    org.display_name,
    org.legal_name,
    org.status,
    org.created_at,
    org.member_count,
    org.open_requests,
    org.open_disputes,
  ].map(cell).join(","));
  const body = `\uFEFF${[header.join(","), ...lines].join("\n")}\n`;
  return new Response(body, {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": "attachment; filename=\"organisations.csv\"",
      "cache-control": "no-store",
    },
  });
}
