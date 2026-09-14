import { notFound, redirect } from "next/navigation";
import services from "@/lib/public-catalogue/services.json";
import { isLocale } from "@/lib/i18n/locale";
export default async function ServiceIntentTransition({ params }: { params: Promise<{ locale: string; code: string }> }) {
  const { locale, code } = await params; if (!isLocale(locale)) notFound();
  const service = services.find(item => item.code.toLowerCase() === code.toLowerCase());
  if (!service) notFound();
  redirect("/" + locale + "/besoin?service=" + encodeURIComponent(service.name));
}
