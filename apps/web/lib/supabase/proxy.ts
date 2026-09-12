import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { getPublicEnvironment } from "@/lib/env";
import { normalizeLocale } from "@/lib/i18n/locale";

export async function refreshSupabaseSession(request: NextRequest) {
  const locale = normalizeLocale(request.nextUrl.pathname.split("/")[1]);
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-matricia-locale", locale);
  let response = NextResponse.next({ request: { headers: requestHeaders } });
  const environment = getPublicEnvironment();
  const supabase = createServerClient(environment.NEXT_PUBLIC_SUPABASE_URL, environment.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (cookiesToSet) => {
        for (const cookie of cookiesToSet) request.cookies.set(cookie.name, cookie.value);
        response = NextResponse.next({ request: { headers: requestHeaders } });
        for (const cookie of cookiesToSet) response.cookies.set(cookie.name, cookie.value, cookie.options);
      },
    },
  });
  const { data: { user } } = await supabase.auth.getUser();
  const isLogin = request.nextUrl.pathname === `/${locale}/connexion`;
  const protectedPrefixes = [
    "tableau-de-bord",
    "organisation",
    "invitations",
    "securite",
    "client",
    "franchise",
    "administration",
  ];
  const isProtected = protectedPrefixes.some((prefix) =>
    request.nextUrl.pathname === `/${locale}/${prefix}`
    || request.nextUrl.pathname.startsWith(`/${locale}/${prefix}/`)
  );
  if (!user && isProtected) return NextResponse.redirect(new URL(`/${locale}/connexion`, request.url));
  if (user && isLogin) return NextResponse.redirect(new URL(`/${locale}/tableau-de-bord`, request.url));
  response.cookies.set("matricia_locale", locale, { sameSite: "lax", secure: request.nextUrl.protocol === "https:", path: "/" });
  return response;
}
