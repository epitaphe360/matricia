import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { resolveClientOrganizationContext } from "@/modules/shared/client-organization-context";
import { isDocumentExpired } from "@/modules/client/data/documents/expiry";
import { loadClientDocumentVault } from "@/modules/client/data/documents/server-repository";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { DocumentVaultPanel } from "@/modules/client/screens/documents/document-vault-panel";
import { DocumentsBoard, SpaceActions } from "@/modules/client/screens/spaces/boards";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";

export default async function Page({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/client/documents` }));
  const result = await loadClientDocumentVault(query.organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/client/documents` }));
  const c = spaceCopy(locale);
  const context = result.status === "success" ? resolveClientOrganizationContext(result.value.organizations.map((organization) => ({ organization_id: organization.id })), query.organizationId) : null;
  const selectedId = context?.status === "success" ? context.membership.organization_id : null;
  const value = result.status === "success" && selectedId ? {
    organizations: result.value.organizations.filter((organization) => organization.id === selectedId),
    documents: result.value.documents.filter((document) => document.organizationId === selectedId),
    targets: result.value.targets.filter((target) => target.organizationId === selectedId),
    bindings: result.value.bindings.filter((binding) => binding.organizationId === selectedId),
  } : null;
  const documents = value?.documents.map((document) => {
    const binding = value.bindings.find((item) => item.documentId === document.id && !item.revokedAt);
    const target = binding ? value.targets.find((item) => item.id === binding.targetId) : null;
    const ext = document.fileName.split(".").pop()?.toLowerCase();
    const kind = ext === "pdf" ? "pdf" as const : ext === "doc" || ext === "docx" ? "docx" as const : ext === "xls" || ext === "xlsx" ? "xlsx" as const : "file" as const;
    const expired = isDocumentExpired(document.expiresOn);
    return {
      id: document.id,
      title: document.fileName,
      folder: target?.label ?? document.type,
      status: expired ? (locale === "ar" ? "للمراجعة" : "À examiner") : (locale === "ar" ? "مشترك" : "Partagé"),
      access: locale === "ar" ? "الأشخاص المخوّلون" : "Personnes habilitées",
      href: `/${locale}/client/documents${space.selectedQuery}`,
      kind,
      tone: expired ? "peach" as const : "mint" as const,
    };
  }) ?? [];
  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="documents" title={c.docsTitle} lead={c.docsLead} kicker={c.kicker} actions={<SpaceActions href={`/${locale}/client/onboarding${space.selectedQuery}`} label={c.addDoc} />}>
      <DocumentsBoard locale={locale} query={space.selectedQuery} organizationName={space.organizationName} documents={documents} toHandle={documents.filter((item) => item.tone === "peach").map((item) => ({ id: item.id, title: item.title, href: item.href, tone: item.tone, action: "examine" as const }))}>
        {value ? <DocumentVaultPanel locale={locale} data={value} keys={{ link: randomUUID(), revoke: Object.fromEntries(value.bindings.map((binding) => [binding.id, randomUUID()])) }} /> : null}
      </DocumentsBoard>
    </ClientAppShell>
  );
}
