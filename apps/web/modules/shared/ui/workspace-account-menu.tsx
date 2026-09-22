import Link from "next/link";
import type { ReactNode } from "react";
import { signOutOfWorkspace } from "@/modules/shared/lib/account-security/sign-out-action";
import { dashboardHomeCopy } from "@/modules/shared/module-hub-copy";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import { Button } from "@/modules/shared/ui/button";

export function WorkspaceAccountMenu({
  locale,
  userEmail,
  returnTo,
  fallbackInitial,
  label,
  displayName,
  className = "client-account",
}: {
  locale: Locale;
  userEmail: string | null;
  returnTo: string;
  fallbackInitial: string;
  label: string;
  displayName?: string;
  className?: string;
}): ReactNode {
  const m = dashboardHomeCopy[locale];
  const initial = (userEmail?.slice(0, 1) || fallbackInitial).toUpperCase();
  return (
    <details className={className}>
      <summary aria-label={label}>
        {displayName ? (
          <>
            <span className="client-account-avatar" aria-hidden>
              {initial}
            </span>
            <span className="client-account-label">{displayName}</span>
          </>
        ) : (
          initial
        )}
      </summary>
      <div>
        <p dir="ltr">{userEmail ?? "—"}</p>
        <Link href={`/${locale}/securite/compte`}>{m.accountTitle}</Link>
        <Link href={`/${locale}/securite/sessions`}>{m.sessionsCta}</Link>
        <form action={signOutOfWorkspace}>
          <input type="hidden" name="locale" value={locale} />
          <input type="hidden" name="returnTo" value={returnTo} />
          <Button type="submit" className="client-ghost-btn">
            {m.signOut}
          </Button>
        </form>
      </div>
    </details>
  );
}
