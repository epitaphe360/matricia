import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { ArrowRight, Headset, Lock, Paperclip, Save, Send } from "lucide-react";
import { resolveClientSpace } from "@/modules/client/data/spaces/context";
import { spaceCopy } from "@/modules/client/data/spaces/copy";
import { AssistancePanel } from "@/modules/client/screens/diagnostics/assistance/assistance-panel";
import { getAssistanceMessages } from "@/modules/client/screens/diagnostics/assistance/messages";
import { ClientAppShell } from "@/modules/client/ui/client-app-shell";
import { createServerAssistedIntelligenceRepository } from "@/modules/shared/lib/assisted-intelligence/server-repository";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import "@/modules/client/screens/diagnostics/diagnostic-connected.css";

export default async function AssistancePage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ organizationId?: string }>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const space = await resolveClientSpace({ locale, organizationId: query.organizationId });
  if (space.status === "unauthenticated") redirect(`/${locale}/connexion`);
  const messages = getAssistanceMessages(locale);
  const result = await (await createServerAssistedIntelligenceRepository()).dashboard();
  const kicker = spaceCopy(locale).kicker;
  const t = locale === "fr"
    ? {
        title: "Demander une assistance",
        lead: "Posez vos questions à un expert Matricia et avancez sereinement.",
        formTitle: "Un expert Matricia peut relire votre analyse avec vous",
        summary: "Résumé de votre demande",
        consent: "J’accepte que les informations nécessaires à la relecture soient partagées avec un conseiller Matricia.",
        draft: "Enregistrer le brouillon",
        send: "Envoyer ma demande",
        history: "Vos demandes d’assistance",
        messages: "Accéder à tous mes messages sécurisés",
        upload: "Glissez-déposez vos fichiers ici ou cliquez pour parcourir",
        privacy: "Vos pièces restent dans l’espace sécurisé et ne sont visibles que des destinataires autorisés.",
      }
    : {
        title: "طلب مساعدة",
        lead: "اطرحوا أسئلة على خبير ماتريسيا وتقدموا باطمئنان.",
        formTitle: "يمكن لخبير ماتريسيا مراجعة تحليلكم معكم",
        summary: "ملخص طلبكم",
        consent: "أوافق على مشاركة المعلومات اللازمة للمراجعة مع مستشار ماتريسيا.",
        draft: "حفظ المسودة",
        send: "إرسال طلبي",
        history: "طلبات المساعدة",
        messages: "الانتقال إلى رسائلي الآمنة",
        upload: "اسحبوا الملفات هنا أو انقروا للاستعراض",
        privacy: "تبقى الملفات في المساحة الآمنة ولا تُعرض إلا للمستلمين المصرح بهم.",
      };

  if (result.status === "error") {
    const forbidden = result.reason === "FORBIDDEN";
    return (
      <ClientAppShell
        locale={locale}
        selectedQuery={space.selectedQuery}
        selectedOrganizationId={space.selectedOrganizationId}
        userEmail={space.userEmail}
        organizationName={space.organizationName}
        active="needs"
        title={forbidden ? messages.forbiddenTitle : messages.errorTitle}
        lead={forbidden ? messages.forbidden : messages.error}
        kicker={kicker}
      >
        <main className="client-page" role={forbidden ? undefined : "alert"}>
          <p>{forbidden ? messages.forbidden : messages.error}</p>
        </main>
      </ClientAppShell>
    );
  }

  const decisionKeys = Object.fromEntries(result.value.suggestions.map((suggestion) => [suggestion.id, randomUUID()]));

  return (
    <ClientAppShell
      locale={locale}
      selectedQuery={space.selectedQuery}
      selectedOrganizationId={space.selectedOrganizationId}
      userEmail={space.userEmail}
      organizationName={space.organizationName}
      active="needs"
      kicker={kicker}
    >
      <main className="client-page">
        <div className="diag-conn">
          <header className="diag-conn-hero">
            <div>
              <h1>{t.title}</h1>
              <p>{t.lead}</p>
            </div>
          </header>

          <div className="diag-conn-split">
            <section className="diag-conn-card">
              <h2><Headset size={18} color="#6f46e8" aria-hidden />{t.formTitle}</h2>
              <p className="diag-conn-callout" data-tone="sky" style={{ marginTop: 12 }}>{messages.safety}</p>
              <div style={{ marginTop: 16 }}>
                <AssistancePanel
                  dashboard={result.value}
                  locale={locale}
                  messages={messages}
                  keys={{ analysis: randomUUID(), similarity: randomUUID(), decisions: decisionKeys }}
                />
              </div>
              <div className="diag-conn-callout" data-tone="sky" style={{ marginTop: 16 }}>
                <Paperclip size={16} aria-hidden />
                <div>
                  <strong>{t.upload}</strong>
                  <p style={{ marginTop: 4 }}><Lock size={14} style={{ display: "inline" }} aria-hidden /> {t.privacy}</p>
                </div>
              </div>
            </section>

            <aside className="diag-conn-stack">
              <section className="diag-conn-card">
                <h2>{t.summary}</h2>
                <dl className="diag-conn-list" style={{ marginTop: 12 }}>
                  <div><dt style={{ color: "#8b93a8", fontSize: "0.75rem" }}>{messages.organization}</dt><dd>{space.organizationName ?? "—"}</dd></div>
                  <div><dt style={{ color: "#8b93a8", fontSize: "0.75rem" }}>{messages.context}</dt><dd>{messages.contexts.CONTEXTUAL_ASSISTANT}</dd></div>
                </dl>
                <label style={{ display: "flex", gap: 10, marginTop: 14, alignItems: "flex-start", fontSize: "0.86rem" }}>
                  <input type="checkbox" defaultChecked style={{ marginTop: 3 }} />
                  <span>{t.consent}</span>
                </label>
                <div className="diag-conn-stack" style={{ marginTop: 14 }}>
                  <button type="button" className="diag-conn-btn-outline"><Save size={15} aria-hidden />{t.draft}</button>
                  <Link href={`/${locale}/client/messages${space.selectedQuery}`} className="diag-conn-btn-grad"><Send size={15} aria-hidden />{t.send}<ArrowRight className="rtl-mirror" size={16} aria-hidden /></Link>
                </div>
              </section>
              <section className="diag-conn-card">
                <div className="diag-conn-item-foot">
                  <h2>{t.history}</h2>
                  <Link href={`/${locale}/client/messages${space.selectedQuery}`} style={{ color: "var(--diag-violet)", fontWeight: 720 }}>{t.messages}</Link>
                </div>
                <ul className="diag-conn-list" style={{ marginTop: 12 }}>
                  {result.value.suggestions.slice(0, 3).map((suggestion) => (
                    <li key={suggestion.id}>
                      <span>•</span>
                      <span>
                        <strong>{messages.kinds[suggestion.kind] ?? suggestion.kind}</strong>
                        <small style={{ display: "block", color: "#8b93a8" }}>{messages.statuses[suggestion.status]}</small>
                      </span>
                    </li>
                  ))}
                  {!result.value.suggestions.length ? <li><span>•</span><span>{messages.noSuggestions}</span></li> : null}
                </ul>
              </section>
            </aside>
          </div>
        </div>
      </main>
    </ClientAppShell>
  );
}
