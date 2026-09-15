import Link from "next/link";
import { z } from "zod";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { buttonVariants } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { cn } from "@/lib/utils";
import { moduleHubCopy, resolveOrganizationContext, visibleModuleRoutes, type ModuleSpace } from "./module-hub-copy";

const membershipRows = z.array(z.object({ id: z.string().uuid(), organization_id: z.string().uuid() }));
const roleRows = z.array(z.object({ role_code: z.string(), revoked_at: z.string().nullable() }));
const securityRows = z.array(z.object({ matched_role_codes: z.array(z.string()) }));
const spaceOrder: readonly ModuleSpace[] = ["client", "provider", "franchise", "admin", "shared"];

export async function ModuleHub({ locale, selectedOrganizationId }: { locale: Locale; selectedOrganizationId: string | null }) {
  const messages = moduleHubCopy[locale], client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  if (!auth.user) return null;
  const membershipsQuery = await client.from("organization_memberships").select("id,organization_id").eq("user_id", auth.user.id).eq("status", "ACTIVE").limit(100);
  const memberships = membershipRows.safeParse(membershipsQuery.data);
  if (membershipsQuery.error || !memberships.success) return <NavigationState messages={messages} />;
  const context = resolveOrganizationContext(memberships.data.map((membership) => ({ membershipId: membership.id, organizationId: membership.organization_id })), selectedOrganizationId);
  const [rolesQuery, securityQuery] = await Promise.all([
    context.selected ? client.from("organization_member_roles").select("role_code,revoked_at").eq("membership_id", context.selected.membershipId).is("revoked_at", null).limit(100) : Promise.resolve({ data: [], error: null }),
    client.rpc("get_my_account_security_requirement"),
  ]);
  const roles = roleRows.safeParse(rolesQuery.data), security = securityRows.safeParse(securityQuery.data);
  if (rolesQuery.error || securityQuery.error || !roles.success || !security.success || security.data.length !== 1) return <NavigationState messages={messages} />;
  const visible = visibleModuleRoutes({ membershipCount: context.selected ? 1 : 0, membershipRoles: new Set(roles.data.map((item) => item.role_code)), platformRoles: new Set(security.data[0]!.matched_role_codes) });
  const spaces = spaceOrder.filter((space) => visible.some((item) => item.space === space));
  return <Card dir={locale === "ar" ? "rtl" : "ltr"}><CardHeader><CardTitle>{messages.title}</CardTitle><CardDescription>{messages.description}</CardDescription></CardHeader><CardContent>{spaces.length === 0 ? <p role="status" className="text-muted-foreground">{messages.empty}</p> : <nav aria-label={messages.title} className="space-y-6">{spaces.map((space) => <section key={space} aria-labelledby={`module-space-${space}`}><h3 id={`module-space-${space}`} className="mb-3 text-sm font-semibold text-slate-600">{messages.spaces[space]}</h3><ul className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">{visible.filter((item) => item.space === space).map((item) => {
    const organizationQuery = item.space !== "admin" && context.selected ? `?organizationId=${encodeURIComponent(context.selected.organizationId)}` : "";
    return <li key={item.id}><Link href={`/${locale}/${item.path}${organizationQuery}`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11 w-full justify-start whitespace-normal text-start")}>{messages.links[item.id]}</Link></li>;
  })}</ul></section>)}</nav>}</CardContent></Card>;
}

function NavigationState({ messages }: { messages: typeof moduleHubCopy.fr | typeof moduleHubCopy.ar }) {
  return <Card><CardHeader><CardTitle>{messages.title}</CardTitle><CardDescription>{messages.description}</CardDescription></CardHeader><CardContent><p role="alert" className="text-sm text-destructive">{messages.unavailable}</p></CardContent></Card>;
}
