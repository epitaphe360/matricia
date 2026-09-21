import Link from "next/link";
import {
  ArrowUpRight,
  BadgeCheck,
  Building2,
  ClipboardCheck,
  Copy,
  FileStack,
  Gauge,
  HandCoins,
  Library,
  LineChart,
  Megaphone,
  Package,
  Scale,
  ShieldAlert,
  ShieldCheck,
  Store,
  Users,
  Wallet,
  Workflow,
} from "lucide-react";
import { z } from "zod";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/modules/shared/ui/card";
import { buttonVariants } from "@/modules/shared/ui/button";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
import { cn } from "@/modules/shared/lib/utils";
import {
  ADMIN_FEATURED_ROUTE_ID,
  ADMIN_NAV_GROUPS,
  moduleHubCopy,
  resolveOrganizationContext,
  visibleModuleRoutes,
  type ModuleRoute,
  type ModuleRouteId,
  type ModuleSpace,
} from "./module-hub-copy";

const membershipRows = z.array(
  z.object({
    id: z.string().uuid(),
    organization_id: z.string().uuid(),
    organizations: z.object({ display_name: z.string().min(1) }).optional(),
  }),
);
const roleRows = z.array(z.object({ role_code: z.string(), revoked_at: z.string().nullable() }));
const securityRows = z.array(z.object({ matched_role_codes: z.array(z.string()) }));
const spaceOrder: readonly ModuleSpace[] = ["client", "provider", "franchise", "admin", "shared"];

const adminIcons: Partial<Record<ModuleRouteId, typeof Gauge>> = {
  "admin-command": Gauge,
  "admin-clients": Building2,
  "admin-client-compliance": ClipboardCheck,
  "admin-providers": Store,
  "admin-finance": Wallet,
  "admin-finance-approvals": HandCoins,
  "admin-tax": Scale,
  "admin-volume": Package,
  "admin-franchise": Users,
  "admin-incentives": BadgeCheck,
  "admin-catalogue": Library,
  "admin-catalogue-validation": ShieldCheck,
  "admin-catalogue-publications": FileStack,
  "admin-cloning": Copy,
  "admin-questionnaires": LineChart,
  "admin-marketing": Megaphone,
  "admin-operations": Workflow,
  "admin-abuse": ShieldAlert,
  "admin-procurement": Package,
};

export async function ModuleHub({ locale, selectedOrganizationId }: { locale: Locale; selectedOrganizationId: string | null }) {
  const messages = moduleHubCopy[locale];
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return null;

  const membershipsQuery = await client
    .from("organization_memberships")
    .select("id,organization_id,organizations(display_name)")
    .eq("user_id", auth.user.id)
    .eq("status", "ACTIVE")
    .order("display_name", { ascending: true, referencedTable: "organizations" })
    .limit(100);
  const memberships = membershipRows.safeParse(membershipsQuery.data);
  if (membershipsQuery.error || !memberships.success) return <NavigationState messages={messages} />;

  const context = resolveOrganizationContext(
    memberships.data.map((membership) => ({
      membershipId: membership.id,
      organizationId: membership.organization_id,
      displayName: membership.organizations?.display_name,
    })),
    selectedOrganizationId,
  );

  const [rolesQuery, securityQuery] = await Promise.all([
    context.selected
      ? client.from("organization_member_roles").select("role_code,revoked_at").eq("membership_id", context.selected.membershipId).is("revoked_at", null).limit(100)
      : Promise.resolve({ data: [], error: null }),
    client.rpc("get_my_account_security_requirement"),
  ]);

  const roles = roleRows.safeParse(rolesQuery.data);
  const security = securityRows.safeParse(securityQuery.data);
  if (rolesQuery.error || securityQuery.error || !roles.success || !security.success || security.data.length !== 1) {
    return <NavigationState messages={messages} />;
  }

  const visible = visibleModuleRoutes({
    membershipCount: context.selected ? 1 : 0,
    membershipRoles: new Set(roles.data.map((item) => item.role_code)),
    platformRoles: new Set(security.data[0]!.matched_role_codes),
  });
  const spaces = spaceOrder.filter((space) => visible.some((item) => item.space === space));

  return (
    <Card dir={locale === "ar" ? "rtl" : "ltr"} className="overflow-hidden border-[#d7e3dc] bg-[#fbfdfc] shadow-[0_18px_48px_rgb(5_53_40_/_8%)]">
      <CardHeader className="border-b border-[#d7e3dc] bg-gradient-to-br from-[#053528] via-[#03261d] to-[#0a3d30] text-white">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#e8d5b5]">{messages.spaces.admin}</p>
        <CardTitle className="text-white">{messages.title}</CardTitle>
        <CardDescription className="max-w-3xl text-white/75">{messages.description}</CardDescription>
      </CardHeader>
      <CardContent className="admin-shell space-y-6 bg-transparent p-4 sm:p-6">
        {spaces.length === 0 ? (
          <p role="status" className="text-[var(--ad-muted)]">{messages.empty}</p>
        ) : (
          <nav aria-label={messages.title} className="space-y-6">
            {spaces.map((space) => {
              const items = visible.filter((item) => item.space === space);
              if (space === "admin") {
                return <AdminSpaceNav key={space} locale={locale} items={items} messages={messages} />;
              }
              return (
                <section key={space} aria-labelledby={`module-space-${space}`} className="admin-hub-space">
                  <h3 id={`module-space-${space}`}>{messages.spaces[space]}</h3>
                  <ul className="admin-hub-links">
                    {items.map((item) => {
                      const organizationQuery = context.selected ? `?organizationId=${encodeURIComponent(context.selected.organizationId)}` : "";
                      return (
                        <li key={item.id}>
                          <Link
                            href={`/${locale}/${item.path}${organizationQuery}`}
                            className={cn(buttonVariants({ variant: "outline" }), "min-h-11 w-full justify-start whitespace-normal border-[#d7e3dc] bg-white text-start hover:border-[#053528]/hover:bg-[#f4f7f5]")}
                          >
                            {messages.links[item.id]}
                          </Link>
                        </li>
                      );
                    })}
                  </ul>
                </section>
              );
            })}
          </nav>
        )}
      </CardContent>
    </Card>
  );
}

function AdminSpaceNav({
  locale,
  items,
  messages,
}: {
  locale: Locale;
  items: readonly ModuleRoute[];
  messages: (typeof moduleHubCopy)["fr"] | (typeof moduleHubCopy)["ar"];
}) {
  const byId = new Map(items.map((item) => [item.id, item]));
  const featured = byId.get(ADMIN_FEATURED_ROUTE_ID);
  const copy = messages.admin;

  return (
    <section aria-labelledby="module-space-admin" className="space-y-5">
      <h3 id="module-space-admin" className="sr-only">{messages.spaces.admin}</h3>

      {featured ? (
        <div className="admin-hero">
          <div className="admin-hero-inner">
            <div>
              <p className="admin-eyebrow">{copy.featuredEyebrow}</p>
              <h4 className="admin-hero-title">{copy.featuredTitle}</h4>
              <p className="admin-hero-lead">{copy.featuredLead}</p>
              <div className="admin-hero-actions">
                <Link href={`/${locale}/${featured.path}`} className="admin-btn-gold">
                  {copy.featuredCta}
                  <ArrowUpRight aria-hidden className="size-4" />
                </Link>
              </div>
            </div>
            <aside className="admin-preview-card" aria-label={copy.featuredTitle}>
              <div className="admin-preview-meta">
                <h2>{messages.links[featured.id]}</h2>
                <span className="admin-pill">+ {items.length}</span>
              </div>
              <ul className="admin-metric-list">
                {ADMIN_NAV_GROUPS.map((group) => {
                  const count = group.routes.filter((routeId) => byId.has(routeId)).length;
                  if (count === 0) return null;
                  return (
                    <li key={group.id}>
                      <span className="admin-icon-tile" aria-hidden>
                        <Gauge className="size-3.5" />
                      </span>
                      <span>{copy.groups[group.id].title}</span>
                      <span dir="ltr">{count}</span>
                    </li>
                  );
                })}
              </ul>
            </aside>
          </div>
        </div>
      ) : null}

      <div className="admin-section">
        <div className="admin-section-head">
          <div>
            <h4 className="text-lg font-semibold tracking-tight text-[var(--ad-ink)]">{copy.groupsLabel}</h4>
            <p>{messages.spaces.admin}</p>
          </div>
        </div>
        <div className="admin-group-grid">
          {ADMIN_NAV_GROUPS.map((group) => {
            const routes = group.routes.map((routeId) => byId.get(routeId)).filter((route): route is ModuleRoute => Boolean(route));
            if (routes.length === 0) return null;
            const groupCopy = copy.groups[group.id];
            return (
              <article key={group.id} className="admin-group-card">
                <h3>{groupCopy.title}</h3>
                <p>{groupCopy.description}</p>
                <ul className="admin-link-list">
                  {routes.map((route) => {
                    const Icon = adminIcons[route.id] ?? Gauge;
                    return (
                      <li key={route.id}>
                        <Link href={`/${locale}/${route.path}`} className="admin-link">
                          <span className="admin-icon-tile" aria-hidden>
                            <Icon className="size-3.5" />
                          </span>
                          <span>
                            <strong>{messages.links[route.id]}</strong>
                            <span>{copy.descriptions[route.id as keyof typeof copy.descriptions]}</span>
                          </span>
                          <ArrowUpRight aria-hidden className="size-4" />
                          <span className="sr-only">{copy.open}</span>
                        </Link>
                      </li>
                    );
                  })}
                </ul>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function NavigationState({ messages }: { messages: (typeof moduleHubCopy)["fr"] | (typeof moduleHubCopy)["ar"] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{messages.title}</CardTitle>
        <CardDescription>{messages.description}</CardDescription>
      </CardHeader>
      <CardContent>
        <p role="alert" className="text-sm text-destructive">{messages.unavailable}</p>
      </CardContent>
    </Card>
  );
}
