import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { isLocale, type Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { listClientComplianceReviews } from "./actions";
import { ComplianceDecisionForm } from "./decision-form";
import { getComplianceMessages } from "./messages";
import { CreateComplianceQuestionForm, EvaluateComplianceForm, ReviewComplianceResponseForm } from "./workflow-forms";

function dateLabel(value: string, locale: Locale): string {
  return new Intl.DateTimeFormat(locale === "fr" ? "fr-MA" : "ar-MA", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
}

export default async function ClientComplianceAdministrationPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const result = await listClientComplianceReviews();
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect("/" + locale + "/connexion");
  const messages = getComplianceMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";

  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-5xl space-y-7">
        <header className="space-y-4">
          <nav aria-label={messages.navigation} className="flex flex-wrap items-center justify-between gap-3">
            <Link href={"/" + locale + "/tableau-de-bord"} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link>
            <Link href={"/" + alternate + "/administration/conformite-clients"} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link>
          </nav>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1>
            <p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p>
          </div>
        </header>

        {result.status === "error" ? (
          result.reason === "MFA_REQUIRED" ? (
            <Alert>
              <AlertTitle>{messages.mfaTitle}</AlertTitle>
              <AlertDescription>
                <p>{messages.mfaDescription}</p>
                <Link href={"/" + locale + "/securite/compte"} className={cn(buttonVariants(), "mt-3 min-h-11")}>{messages.configureMfa}</Link>
              </AlertDescription>
            </Alert>
          ) : result.reason === "FORBIDDEN" ? (
            <Alert variant="destructive"><AlertTitle>{messages.forbiddenTitle}</AlertTitle><AlertDescription><p>{messages.forbiddenDescription}</p></AlertDescription></Alert>
          ) : (
            <Alert variant="destructive">
              <AlertTitle>{messages.unavailableTitle}</AlertTitle>
              <AlertDescription>
                <p>{messages.unavailable}</p>
                <Link href={"/" + locale + "/administration/conformite-clients"} className={cn(buttonVariants({ variant: "outline" }), "mt-3 min-h-11")}>{messages.retry}</Link>
              </AlertDescription>
            </Alert>
          )
        ) : result.cases.length === 0 ? (
          <p className="rounded-lg border bg-card p-5 text-sm text-muted-foreground">{messages.empty}</p>
        ) : (
          <section aria-label={messages.title}>
            <ul className="grid gap-5">
              {result.cases.map((complianceCase) => {
                const canDecide = complianceCase.status === "UNDER_REVIEW" || complianceCase.status === "RESPONSE_RECEIVED";
                const canEvaluate = complianceCase.status !== "VERIFIED"
                  && complianceCase.status !== "REJECTED"
                  && complianceCase.status !== "SUSPENDED";
                return (
                  <li key={complianceCase.id}>
                    <Card className={canDecide ? "border-primary/40 shadow-lg" : undefined}>
                      <CardHeader>
                        <div className="flex flex-wrap items-start justify-between gap-3">
                          <div>
                            <CardTitle className="text-xl">{complianceCase.organizationName ?? messages.unknownOrganization}</CardTitle>
                            <CardDescription>{messages.profileVersion}: {complianceCase.profileVersion ?? messages.noProfile}</CardDescription>
                          </div>
                          <Badge variant="outline">{messages.statuses[complianceCase.status]}</Badge>
                        </div>
                      </CardHeader>
                      <CardContent className="space-y-5">
                        <dl className="grid gap-3 text-sm sm:grid-cols-2">
                          <div><dt className="text-muted-foreground">{messages.submitted}</dt><dd className="mt-1">{complianceCase.submittedAt ? <time dateTime={complianceCase.submittedAt}>{dateLabel(complianceCase.submittedAt, locale)}</time> : messages.notSubmitted}</dd></div>
                          <div><dt className="text-muted-foreground">{messages.updated}</dt><dd className="mt-1"><time dateTime={complianceCase.updatedAt}>{dateLabel(complianceCase.updatedAt, locale)}</time></dd></div>
                        </dl>
                        {complianceCase.publicReason ? <div><h3 className="text-sm font-medium">{messages.currentReason}</h3><p className="mt-1 whitespace-pre-wrap text-sm text-muted-foreground">{complianceCase.publicReason}</p></div> : null}
                        <div>
                          <h3 className="text-sm font-medium">{messages.evidence}</h3>
                          {complianceCase.evidence.length === 0 ? <p className="mt-1 text-sm text-muted-foreground">{messages.noEvidence}</p> : (
                            <ul className="mt-2 flex flex-wrap gap-2">
                              {complianceCase.evidence.map((evidence, index) => <li key={evidence.type + "-" + index}><Badge variant="secondary">{messages.evidenceTypes[evidence.type]} — {messages.evidenceStatuses[evidence.status]}</Badge></li>)}
                            </ul>
                          )}
                        </div>
                        {canEvaluate ? (
                          <section className="border-t pt-5" aria-labelledby={"evaluate-" + complianceCase.id}>
                            <h3 id={"evaluate-" + complianceCase.id} className="mb-3 text-lg font-semibold">{messages.evaluateTitle}</h3>
                            <EvaluateComplianceForm complianceCaseId={complianceCase.id} idempotencyKey={randomUUID()} locale={locale} messages={messages} />
                          </section>
                        ) : null}
                        <section className="border-t pt-5" aria-labelledby={"anomalies-" + complianceCase.id}>
                          <h3 id={"anomalies-" + complianceCase.id} className="text-lg font-semibold">{messages.anomalies}</h3>
                          {complianceCase.anomalies.length === 0 ? (
                            <p className="mt-2 text-sm text-muted-foreground">{messages.noAnomalies}</p>
                          ) : (
                            <ul className="mt-3 grid gap-3">
                              {complianceCase.anomalies.map((anomaly) => {
                                const hasActiveQuestion = complianceCase.questions.some((question) =>
                                  question.anomalyId === anomaly.id && (question.status === "OPEN" || question.status === "ANSWERED"));
                                return (
                                  <li key={anomaly.id} className="min-w-0 rounded-lg border bg-muted/20 p-4">
                                    <div className="flex flex-wrap items-center gap-2">
                                      <Badge variant={anomaly.severity === "CRITICAL" ? "destructive" : "secondary"}>{messages.anomalySeverities[anomaly.severity]}</Badge>
                                      <Badge variant="outline">{messages.anomalyStatuses[anomaly.status]}</Badge>
                                      <span className="text-xs font-medium text-muted-foreground">{anomaly.blocking ? messages.blocking : messages.nonBlocking}</span>
                                    </div>
                                    <p className="mt-3 break-words text-sm font-medium">{anomaly.code}</p>
                                    <p className="mt-2 whitespace-pre-wrap text-sm leading-6" lang={locale} dir={locale === "ar" ? "rtl" : "ltr"}>
                                      {locale === "ar" ? anomaly.messageAr : anomaly.messageFr}
                                    </p>
                                    {anomaly.status === "OPEN" && !hasActiveQuestion ? (
                                      <CreateComplianceQuestionForm anomalyId={anomaly.id} idempotencyKey={randomUUID()} requestAnchor={new Date().toISOString()} locale={locale} messages={messages} />
                                    ) : null}
                                  </li>
                                );
                              })}
                            </ul>
                          )}
                        </section>
                        <section className="border-t pt-5" aria-labelledby={"questions-" + complianceCase.id}>
                          <h3 id={"questions-" + complianceCase.id} className="text-lg font-semibold">{messages.questions}</h3>
                          {complianceCase.questions.length === 0 ? (
                            <p className="mt-2 text-sm text-muted-foreground">{messages.noQuestions}</p>
                          ) : (
                            <ul className="mt-3 grid gap-3">
                              {complianceCase.questions.map((question) => (
                                <li key={question.id} className="min-w-0 rounded-lg border bg-background p-4">
                                  <div className="flex flex-wrap items-center justify-between gap-2">
                                    <Badge variant="outline">{messages.questionStatuses[question.status]}</Badge>
                                    <p className="text-xs text-muted-foreground">{messages.dueAt}: <time dateTime={question.dueAt}>{dateLabel(question.dueAt, locale)}</time></p>
                                  </div>
                                  <p className="mt-3 whitespace-pre-wrap text-sm leading-6" lang={locale} dir={locale === "ar" ? "rtl" : "ltr"}>
                                    {locale === "ar" ? question.textAr : question.textFr}
                                  </p>
                                  {question.expectedDocumentType ? <p className="mt-2 break-words text-xs text-muted-foreground">{messages.expectedDocument}: {messages.expectedDocumentTypes[question.expectedDocumentType as keyof typeof messages.expectedDocumentTypes] ?? messages.otherExpectedDocument}</p> : null}
                                  {question.latestResponse ? (
                                    <div className="mt-4 rounded-lg border-s-4 border-primary bg-muted/40 p-4">
                                      <h4 className="text-sm font-semibold">{messages.latestResponse}</h4>
                                      <p className="mt-1 text-xs text-muted-foreground">
                                        {messages.responseVersion} {question.latestResponse.version} · {messages.responseSubmitted} <time dateTime={question.latestResponse.submittedAt}>{dateLabel(question.latestResponse.submittedAt, locale)}</time>
                                      </p>
                                      <p className="mt-3 whitespace-pre-wrap break-words text-sm leading-6" dir="auto" lang={locale}>{question.latestResponse.text}</p>
                                    </div>
                                  ) : null}
                                  {question.status === "ANSWERED" && question.latestResponse ? (
                                    <div className="mt-4 border-t pt-4">
                                      <h4 className="text-sm font-semibold">{messages.responseDecision}</h4>
                                      <ReviewComplianceResponseForm questionId={question.id} idempotencyKey={randomUUID()} locale={locale} messages={messages} />
                                    </div>
                                  ) : null}
                                </li>
                              ))}
                            </ul>
                          )}
                        </section>
                        {canDecide ? (
                          <div className="border-t pt-5">
                            <h3 className="mb-4 text-lg font-semibold">{messages.decisionTitle}</h3>
                            <ComplianceDecisionForm complianceCaseId={complianceCase.id} idempotencyKey={randomUUID()} locale={locale} messages={messages} />
                          </div>
                        ) : null}
                      </CardContent>
                    </Card>
                  </li>
                );
              })}
            </ul>
          </section>
        )}
      </div>
    </main>
  );
}
