import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { resolveClientOrganizationContext } from "@/lib/client-organization-context";
import { loadClientDocumentVault } from "@/lib/client-documents/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { DocumentVaultPanel } from "./document-vault-panel";
import { messages } from "./messages";

export default async function Page({ params, searchParams }: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const result = await loadClientDocumentVault(organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const copy = messages[locale], alternate = locale === "fr" ? "ar" : "fr";
  const context = result.status === "success" ? resolveClientOrganizationContext(result.value.organizations.map((organization) => ({ organization_id: organization.id })), organizationId) : null;
  const selectedId = context?.status === "success" ? context.membership.organization_id : null;
  const value = result.status === "success" && selectedId ? {
    organizations: result.value.organizations.filter((organization) => organization.id === selectedId),
    documents: result.value.documents.filter((document) => document.organizationId === selectedId),
    targets: result.value.targets.filter((target) => target.organizationId === selectedId),
    bindings: result.value.bindings.filter((binding) => binding.organizationId === selectedId),
  } : null;
  const organizationQuery = organizationId ? `?organizationId=${encodeURIComponent(organizationId)}` : "";
  return <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6"><div className="mx-auto max-w-6xl space-y-7">
    <nav aria-label={copy.nav} className="flex flex-wrap justify-between gap-3"><Link href={`/${locale}/tableau-de-bord${organizationQuery}`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{copy.back}</Link><Link href={`/${alternate}/client/documents${organizationQuery}`} hrefLang={alternate} className="min-h-11 px-3 py-2 text-primary underline">{copy.language}</Link></nav>
    <header><p className="text-xs font-semibold uppercase tracking-[.18em] text-primary">{copy.eyebrow}</p><h1 className="mt-2 text-3xl font-semibold">{copy.title}</h1><p className="mt-3 max-w-3xl text-muted-foreground">{copy.description}</p></header>
    <Alert><AlertDescription>{copy.safety}</AlertDescription></Alert>
    {result.status === "error" || !value ? <p role="alert" className="text-destructive">{copy.loadError}</p> : <DocumentVaultPanel locale={locale} data={value} keys={{ link: randomUUID(), revoke: Object.fromEntries(value.bindings.map((binding) => [binding.id, randomUUID()])) }}/>}</div></main>;
}
