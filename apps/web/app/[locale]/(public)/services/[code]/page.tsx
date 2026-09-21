import Link from "next/link";
import { notFound } from "next/navigation";
import services from "@/modules/public/data/catalogue/services.json";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";
import { ServiceNeedComposer } from "../service-need-composer";

export default async function ServiceIntentGuide({ params }: { params: Promise<{ locale: string; code: string }> }) {
  const { locale, code } = await params;
  if (!isLocale(locale)) notFound();
  const service = services.find((item) => item.code.toLowerCase() === code.toLowerCase());
  if (!service) notFound();
  const fr = locale === "fr";

  return (
    <main id="contenu-principal" className="public-page pb-16">
      <section className="public-wrap grid gap-10 py-12 lg:grid-cols-[1.15fr_.85fr] lg:items-center">
        <div>
          <p className="text-sm text-slate-500">
            <Link href={`/${locale}`}>{fr ? "Accueil" : "الرئيسية"}</Link>
            {" / "}
            <Link href={`/${locale}/services`}>{fr ? "Nos services" : "خدماتنا"}</Link>
            {" / "}
            <span lang="fr">{service.name}</span>
          </p>
          <p className="journey-eyebrow mt-6">{fr ? "Guide Matricia" : "دليل ماتريسيا"}</p>
          <h1 lang="fr">{service.name}</h1>
          <p className="public-lead mt-4">
            {fr
              ? "Matricia vous aide à structurer votre besoin pour le formuler clairement et, après validation, vous permettre de consulter des professionnels adaptés."
              : "تساعدكم ماتريسيا على تنظيم احتياجكم لصياغته بوضوح، ثم بعد التأكيد يمكن استشارة المهنيين المناسبين."}
          </p>
        </div>
        <PublicPhoto scene="koutoubia" caption={fr ? "Des idées claires pour un Maroc qui avance" : "أفكار واضحة لمغرب يتقدم"} />
      </section>
      <ol className="public-wrap journey-provider-steps" aria-label={fr ? "Parcours guidé" : "مسار موجّه"}>
        <li><span>1</span>{fr ? "Décrivez votre situation" : "صفوا وضعكم"}</li>
        <li><span>2</span>{fr ? "Matricia structure le besoin" : "تنظم ماتريسيا الاحتياج"}</li>
        <li><span>3</span>{fr ? "Vous confirmez le périmètre" : "تؤكدون النطاق"}</li>
        <li><span>4</span>{fr ? "Des professionnels adaptés peuvent être consultés après validation" : "يمكن استشارة المهنيين المناسبين بعد التأكيد"}</li>
      </ol>
      <div className="public-wrap">
        <ServiceNeedComposer locale={locale} serviceCode={service.code} serviceName={service.name} description={service.description} />
      </div>
      <section className="public-wrap mt-6 public-card max-w-none">
        <h2>{fr ? "Pas encore sûr de votre besoin ?" : "لستم متأكدين بعد من احتياجكم؟"}</h2>
        <p className="public-muted mt-2">{fr ? "Répondez à quelques questions pour être guidé pas à pas." : "أجيبوا عن بعض الأسئلة للتوجيه خطوة بخطوة."}</p>
        <Link className="journey-secondary mt-4" href={`/${locale}/diagnostic`}>{fr ? "Commencer un diagnostic" : "بدء تقييم أولي"}</Link>
      </section>
    </main>
  );
}
