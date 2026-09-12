import Link from "next/link";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { buttonVariants } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { moduleHubCopy } from "./module-hub-copy";

export function ModuleHub({ locale }: { locale: Locale }) {
  const messages = moduleHubCopy[locale];
  return <Card>
    <CardHeader>
      <CardTitle>{messages.title}</CardTitle>
      <CardDescription>{messages.description}</CardDescription>
    </CardHeader>
    <CardContent>
      <nav aria-label={messages.title} className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {messages.links.map(([label, path]) => <Link key={path} href={`/${locale}/${path}`} className={cn(buttonVariants({ variant: "outline" }), "min-h-11 justify-start whitespace-normal text-start")}>{label}</Link>)}
      </nav>
    </CardContent>
  </Card>;
}
