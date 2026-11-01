import {InterventionForm} from "@/modules/provider/screens/qualification/intervention-form";
import { notFound, redirect } from "next/navigation";
import { connexionHref } from "@/modules/shared/lib/auth/connexion-href";
import { Alert, AlertTitle } from "@/modules/shared/ui/alert";
import { resolveProviderSpace } from "@/modules/provider/data/spaces/context";
import { providerCopy } from "@/modules/provider/data/spaces/copy";
import { loadProviderDashboard } from "@/modules/provider/data/qualification/repository";
import { QualificationBoard } from "@/modules/provider/screens/spaces/boards";
import { getProviderMessages } from "@/modules/provider/screens/qualification/messages";
import { QualificationForms } from "@/modules/provider/screens/qualification/qualification-forms";
import { RegionsForm } from "@/modules/provider/screens/qualification/regions-form";
import { loadProviderRegions } from "@/modules/provider/data/qualification/regions-repository";
import { ProviderActions, ProviderAppShell } from "@/modules/provider/ui/provider-app-shell";
import { ProviderProfileRail } from "@/modules/provider/ui/provider-profile-rail";
import { isLocale } from "@/modules/shared/lib/i18n/locale";

export default async function ProviderQualificationPage({ params, searchParams }: { params: Promise<{ locale: string }>; searchParams: Promise<{ organizationId?: string }> }) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveProviderSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(connexionHref(locale, { next: `/${locale}/sous-traitant/qualification` }));
  const messages = getProviderMessages(locale);
  const result = await loadProviderDashboard(query.organizationId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(connexionHref(locale, { next: `/${locale}/sous-traitant/qualification` }));
  const regions = result.status === "success" ? await loadProviderRegions(result.dashboard.organizationId) : [];
  const c = providerCopy(locale);
  return (
    <ProviderAppShell locale={locale} organizations={space.organizations} selectedQuery={space.selectedQuery} selectedOrganizationId={space.selectedOrganizationId} userEmail={space.userEmail} active="qualify" title={c.qualTitle} lead={c.qualLead} kicker={c.kicker} actions={<ProviderActions href="#qualification" label={c.completeFolder} />}>
      <div className="provider-settings-layout">
        <ProviderProfileRail locale={locale} query={space.selectedQuery} active="profile" />
        <div className="client-stack">
      {result.status==="success"&&!result.dashboard.identityReview?.verified?<aside role="status" className="client-card border-amber-500"><h2>{locale==="ar"?"مراجعة الهوية القانونية مطلوبة":"Revue de l’identité juridique requise"}</h2><p>{locale==="ar"?"يلزم تأكيد الهوية القانونية الحالية من المسؤول المختص بعد فحص الوثائق القانونية والضريبية والتأمين. لا تتيح الموافقة السابقة فرصاً جديدة بعد تغيير الهوية. تبقى ملفات المهام السابقة متاحة.":"Un responsable doit vérifier l’identité légale courante contre les pièces légales, fiscales et d’assurance analysées. Une ancienne validation ne suffit pas pour de nouvelles opportunités. Les dossiers des missions précédentes restent accessibles."}</p><a href="#documents" className="client-text-link">{locale==="ar"?"تحديث المستندات":"Mettre à jour les pièces"}</a><a href={`/${locale}/sous-traitant/messages${space.selectedQuery}`} className="client-text-link ms-4">{locale==="ar"?"التواصل مع فريق المراجعة":"Contacter l’équipe de revue"}</a></aside>:null}
      <QualificationBoard locale={locale} query={space.selectedQuery} dashboard={result.status === "success" ? result.dashboard : null} />
      <details id="qualification" className="client-ops" open>
        <summary>{c.opsQual}</summary>
        {result.status === "error" ? (
          <Alert data-error-reason={result.reason} variant={result.reason === "NO_PROVIDER_ORGANIZATION" ? "default" : "destructive"}>
            <AlertTitle>{result.reason === "NO_PROVIDER_ORGANIZATION" ? messages.noProvider : messages.loadError}</AlertTitle>
          </Alert>
        ) : (
          <>
            {result.dashboard.profile?<InterventionForm organizationId={result.dashboard.organizationId} current={result.dashboard.interventionModes??[]} version={result.dashboard.interventionModeVersion??0} locale={locale} idempotencyKey={crypto.randomUUID()}/>:null}
            <QualificationForms dashboard={result.dashboard} locale={locale} messages={messages} keys={{ profile: crypto.randomUUID(), service: crypto.randomUUID(), capacity: crypto.randomUUID(), document: crypto.randomUUID() }} />
            {regions === null ? (
              <Alert variant="destructive" className="mt-6"><AlertTitle>{messages.regionsLoadError}</AlertTitle></Alert>
            ) : result.dashboard.profile ? (
              <div className="mt-6"><RegionsForm organizationId={result.dashboard.organizationId} locale={locale} messages={messages} current={regions} idempotencyKey={crypto.randomUUID()} /></div>
            ) : null}
          </>
        )}
      </details>
        </div>
      </div>
    </ProviderAppShell>
  );
}
