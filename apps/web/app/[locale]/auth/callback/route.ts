import { NextResponse, type NextRequest } from "next/server";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { isLocale } from "@/lib/i18n/locale";

export async function GET(request: NextRequest, { params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) return NextResponse.redirect(new URL("/fr/connexion", request.url));
  const code = request.nextUrl.searchParams.get("code");
  const requested = request.nextUrl.searchParams.get("next");
  const nextPath = requested && requested.startsWith("/" + locale + "/") && !requested.startsWith("//") && !requested.includes("\\") ? requested : "/" + locale + "/tableau-de-bord";
  if (code) {
    const supabase = await getSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(nextPath, request.url));
  }
  return NextResponse.redirect(new URL(`/${locale}/connexion`, request.url));
}
