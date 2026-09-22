import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { ActionPanel } from "@/modules/client/screens/litiges/action-panel";
import { getDisputeMessages } from "@/modules/client/screens/litiges/messages";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { DisputesBoard } from "@/modules/client/screens/spaces/disputes-board";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { formatMinorAmount } from "@/modules/shared/lib/disputes/model";
import { createServerDisputesRepository } from "@/modules/shared/lib/disputes/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

function date(value: string | null, locale: "fr" | "ar") {
  return value ? new Intl.DateTimeFormat(locale === "ar" ? "ar-MA" : "fr-MA", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "—";
}

export default async function DisputePage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string; caseId: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const { locale, caseId } = await params;
  const { organizationId } = await searchParams;
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const repository = await createServerDisputesRepository(space.selectedOrganizationId ?? organizationId);
  const [list, result] = await Promise.all([repository.list(), repository.detail(caseId)]);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (list.status === "error" && list.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  if (result.status === "error" || !result.value) notFound();
  const d = result.value;
  const m = getDisputeMessages(locale);
  const c = spaceCopy(locale);
  const keys = Object.fromEntries(["respond", "appeal", "decide", "propose", "approve", "activate"].map((x) => [x, randomUUID()]));

  return (
    <ClientAppShell locale={locale} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} organizationName={space.organizationName} active="missions" title={m.title} lead={d.obligationKey} kicker={c.kicker}>
      <DisputesBoard
        locale={locale}
        query={space.selectedQuery}
        organizationName={space.organizationName}
        cases={list.status === "success" ? list.value.cases : [d]}
        selected={d}
        messages={m}
        canOpen={list.status === "success" ? list.value.canOpen : false}
      >
        <ActionPanel locale={locale} d={d} m={m} keys={keys} />
      </DisputesBoard>
      <details className="client-ops">
        <summary>{m.actions}</summary>
        <dl className="client-fact-grid">
          <div><small>{m.policy}</small><span>{d.policyVersion}</span></div>
          <div><small>{m.deadline}</small><span>{date(d.responseDueAt, locale)}</span></div>
          <div><small>{m.reviewDeadline}</small><span>{date(d.reviewDueAt, locale)}</span></div>
          <div><small>{m.appealDeadline}</small><span>{date(d.appealDueAt, locale)}</span></div>
        </dl>
        {d.decisions.map((item) => (
          <article key={item.id} className="client-card">
            <h3>{m.decisionNumber}{item.number} · {m.outcomes[item.outcome]}</h3>
            <p>{item.reason}</p>
          </article>
        ))}
        {d.appeal ? <article className="client-card"><h3>{m.appealTitle}</h3><p>{d.appeal.grounds}</p></article> : null}
        {d.reassignment ? (
          <article className="client-card">
            <h3>{m.reassignment}</h3>
            <p>{m.originalCost}: <strong dir="ltr">{formatMinorAmount(d.reassignment.originalCostMinor, d.reassignment.currency, locale)}</strong></p>
            <p>{m.costDelta}: <strong dir="ltr">{formatMinorAmount(d.reassignment.costDeltaMinor ?? "0", d.reassignment.currency, locale)}</strong></p>
          </article>
        ) : null}
      </details>
    </ClientAppShell>
  );
}
