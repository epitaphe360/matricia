import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Button } from "@/modules/shared/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { getDictionary } from "@/modules/shared/lib/i18n/dictionaries";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { CompanyBoard, SpaceActions } from "@/modules/client/screens/spaces/boards";
import { ConnectedAppShell } from "@/modules/shared/ui/connected-app-shell";
import { listOrganizationRoles } from "@/app/[locale]/organisation/roles/actions";
import { getRoleMessages } from "@/app/[locale]/organisation/roles/messages";
import { OrganizationForm } from "./organization-form";

export default async function OrganizationPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ role?: string; organizationId?: string }> }) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(connexionHref(locale, { next: `/${locale}/organisation` }));
  const messages = getDictionary(locale).organization;
  const alternate = locale === "fr" ? "ar" : "fr";
  const defaultRole = query.role === "fournisseur" ? "PROVIDER_OWNER" : query.role === "franchise" ? "FRANCHISE_OWNER" : "CLIENT_OWNER";
  const roleQuery = query.role === "fournisseur" || query.role === "franchise" ? `?role=${query.role}` : "";
  if (query.role === "fournisseur" || query.role === "franchise") {
    return (
      <main className="min-h-dvh bg-muted/40 px-4 py-8 sm:px-6 sm:py-12">
        <div className="mx-auto w-full max-w-2xl space-y-5">
          <nav aria-label={messages.backToDashboard} className="flex flex-wrap items-center justify-between gap-3">
            <Button asChild variant="ghost"><Link href={`/${locale}/tableau-de-bord`}>{messages.backToDashboard}</Link></Button>
            <Link href={`/${alternate}/organisation${roleQuery}`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary">{messages.language}</Link>
          </nav>
          <Card className="shadow-xl">
            <CardHeader className="space-y-3">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
              <CardTitle className="text-2xl sm:text-3xl">{messages.title}</CardTitle>
              <CardDescription className="leading-6">{messages.description}</CardDescription>
            </CardHeader>
            <CardContent><OrganizationForm locale={locale} idempotencyKey={randomUUID()} defaultRole={defaultRole} /></CardContent>
          </Card>
        </div>
      </main>
    );
  }
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/organisation` }));
  const c = spaceCopy(locale);
  const roles = await listOrganizationRoles();
  const roleMessages = getRoleMessages(locale);
  const selectedOrgName = space.selectedOrganizationId
    ? roles.status === "success"
      ? roles.organizations.find((org) => org.id === space.selectedOrganizationId)?.displayName ?? space.organizationName
      : space.organizationName
    : null;
  const people = roles.status === "success"
    ? roles.memberships
        .filter((member) => !selectedOrgName || member.organizationName === selectedOrgName)
        .map((member) => ({
          id: member.id,
          name: member.isCurrentUser ? (locale === "ar" ? "أنتم" : "Vous") : (member.organizationName ?? roleMessages.anotherMember),
          role: member.roles[0] ? roleMessages.roles[member.roles[0]] : roleMessages.noRole,
        }))
    : [];
  return (
    <ConnectedAppShell
      locale={locale}
      organizationId={query.organizationId}
      title={c.orgTitle}
      lead={c.orgLead}
      kicker={c.kicker}
      clientActive="company"
      providerActive="company"
      franchiseActive="governance"
      actions={<SpaceActions href="#modifier" label={c.editInfo} />}
    >
      <CompanyBoard locale={locale} query={space.selectedQuery} organizationName={space.organizationName} alternate={alternate} people={people} />
      <details id="modifier" className="client-ops">
        <summary>{c.opsOrg}</summary>
        <OrganizationForm locale={locale} idempotencyKey={randomUUID()} defaultRole={defaultRole} />
      </details>
    </ConnectedAppShell>
  );
}
