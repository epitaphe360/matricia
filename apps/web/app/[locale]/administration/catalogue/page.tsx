import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { buttonVariants } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { createServerCatalogBuilderRepository } from "@/lib/catalogue-builder/server-repository";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getBuilderMessages } from "./messages";
import { ReleaseWorkflow } from "./release-workflow";
import { QuestionBuilder } from "./question-builder";

export const dynamic = "force-dynamic";

function queryValue(value: string | string[] | undefined): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

export default async function CatalogueReleaseAdministrationPage({ params, searchParams }: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const [{ locale }, query] = await Promise.all([params, searchParams]);
  if (!isLocale(locale)) notFound();
  const libraryId = queryValue(query.library);
  const selectedServiceId = queryValue(query.service);
  const repository = await createServerCatalogBuilderRepository();
  const result = await repository.loadWorkspace(libraryId);
  if (result.status === "error" && result.reason === "UNAUTHENTICATED") redirect(`/${locale}/connexion`);
  const messages = getBuilderMessages(locale);
  const alternate = locale === "fr" ? "ar" : "fr";

  const selectedLibrary = result.status === "success" ? result.value.libraries.find((item) => item.id === libraryId) : undefined;
  const selectedService = result.status === "success" ? result.value.services.find((item) => item.id === selectedServiceId) : undefined;

  return (
    <main className="min-h-dvh bg-muted/40 px-4 py-6 sm:px-6 sm:py-8">
      <div className="mx-auto max-w-7xl space-y-7">
        <header className="space-y-4">
          <nav aria-label={messages.nav} className="flex flex-wrap items-center justify-between gap-3">
            <Link href={`/${locale}/tableau-de-bord`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11")}>{messages.back}</Link>
            <Link href={`/${alternate}/administration/catalogue`} hrefLang={alternate} className="rounded-md px-3 py-2 text-sm font-medium text-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2">{messages.language}</Link>
          </nav>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{messages.eyebrow}</p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight">{messages.title}</h1>
            <p className="mt-3 max-w-3xl leading-7 text-muted-foreground">{messages.description}</p>
          </div>
        </header>

        {result.status === "error" ? (
          <Alert variant="destructive">
            <AlertTitle>{messages.unavailable}</AlertTitle>
            <AlertDescription><Link href={`/${locale}/administration/catalogue`} className={cn(buttonVariants({ variant: "outline" }), "mt-2 min-h-11")}>{messages.retry}</Link></AlertDescription>
          </Alert>
        ) : (
          <>
            <Card>
              <CardHeader><CardTitle><h2>{messages.selection}</h2></CardTitle></CardHeader>
              <CardContent>
                {result.value.libraries.length === 0 ? <p className="text-sm text-muted-foreground">{messages.noLibraries}</p> : (
                  <form method="get" className="grid items-end gap-4 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto]">
                    <div className="min-w-0 space-y-2">
                      <Label htmlFor="catalogue-library">{messages.library}</Label>
                      <select id="catalogue-library" name="library" defaultValue={libraryId ?? ""} dir={libraryId ? "ltr" : locale === "ar" ? "rtl" : "ltr"} required className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
                        <option value="" dir={locale === "ar" ? "rtl" : "ltr"}>{messages.chooseLibrary}</option>
                        {result.value.libraries.map((library) => <option key={library.id} value={library.id} dir="ltr">{library.code}</option>)}
                      </select>
                    </div>
                    <div className="min-w-0 space-y-2">
                      <Label htmlFor="catalogue-service">{messages.service}</Label>
                      <select id="catalogue-service" name="service" defaultValue={selectedService?.id ?? ""} dir={selectedService ? "ltr" : locale === "ar" ? "rtl" : "ltr"} className="min-h-11 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
                        <option value="" dir={locale === "ar" ? "rtl" : "ltr"}>{selectedLibrary ? messages.chooseService : messages.chooseLibrary}</option>
                        {result.value.services.map((service) => <option key={service.id} value={service.id} dir="ltr">{service.code}</option>)}
                      </select>
                    </div>
                    <button type="submit" className={cn(buttonVariants(), "min-h-11 w-full md:w-auto")}>{messages.open}</button>
                  </form>
                )}
                {selectedLibrary && result.value.services.length === 0 ? <p className="mt-4 text-sm text-muted-foreground">{messages.noServices}</p> : null}
              </CardContent>
            </Card>

            {selectedLibrary && selectedService ? <>
              <QuestionBuilder locale={locale} library={selectedLibrary} service={selectedService} messages={messages} commandIdentity={{ idempotencyKey: randomUUID(), correlationId: randomUUID() }} />
              <ReleaseWorkflow locale={locale} library={selectedLibrary} service={selectedService} messages={messages} commandIdentities={{
                create: { idempotencyKey: randomUUID(), correlationId: randomUUID() },
                add: { idempotencyKey: randomUUID(), correlationId: randomUUID() },
                submit: { idempotencyKey: randomUUID(), correlationId: randomUUID() },
              }} />
            </> : null}
          </>
        )}
      </div>
    </main>
  );
}
