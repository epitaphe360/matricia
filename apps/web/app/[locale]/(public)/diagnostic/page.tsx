import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { isLocale } from "@/lib/i18n/locale";
import { localizedRouteMetadata } from "@/lib/seo/metadata";
import { PrediagnosticFlow } from "@/components/public-journey/prediagnostic-flow";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { savePublicDiagnosticIntake } from "./actions";
export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params; if (!isLocale(locale)) return {};
  return localizedRouteMetadata(locale, "/diagnostic", locale === "fr" ? "Prédiagnostic entreprise | Matricia" : "تقييم أولي للشركة | ماتريسيا", locale === "fr" ? "Comprenez vos priorités avant d’agir." : "افهموا أولوياتكم قبل التحرك.");
}
export default async function DiagnosticPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params; if (!isLocale(locale)) notFound();
  const client = await getSupabaseServerClient();
  const { data: auth } = await client.auth.getUser();
  let organizations: { id: string; name: string }[] = [];
  if (auth.user) {
    const memberships = await client.from("organization_memberships").select("id,organization_id").eq("user_id", auth.user.id).eq("status", "ACTIVE").limit(100);
    const membershipIds = (memberships.data ?? []).map((membership) => membership.id);
    const roles = membershipIds.length ? await client.from("organization_member_roles").select("membership_id").in("membership_id", membershipIds).in("role_code", ["CLIENT_OWNER", "CLIENT_ADMIN", "CLIENT_BUYER"]).is("revoked_at", null).limit(300) : { data: [], error: null };
    const writableMembershipIds = new Set((roles.data ?? []).map((role) => role.membership_id));
    const organizationIds = [...new Set((memberships.data ?? []).filter((membership) => writableMembershipIds.has(membership.id)).map((membership) => membership.organization_id))];
    const organizationResult = organizationIds.length ? await client.from("organizations").select("id,display_name").in("id", organizationIds).order("display_name").limit(100) : { data: [], error: null };
    organizations = (organizationResult.data ?? []).map((organization) => ({ id: organization.id, name: organization.display_name }));
  }
  return <PrediagnosticFlow locale={locale} organizations={organizations} authenticated={Boolean(auth.user)} saveAction={savePublicDiagnosticIntake} />;
}
