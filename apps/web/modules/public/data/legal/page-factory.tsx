import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { getLegalDocument, type LegalDocumentId } from "@/modules/public/data/legal/documents";
import { CookiePreferences } from "@/modules/public/data/legal/cookie-preferences";
import { localizedRouteMetadata } from "@/modules/shared/lib/seo/metadata";

export function createLegalPage(documentId: LegalDocumentId) {
  async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
    const { locale } = await params;
    if (!isLocale(locale)) return {};
    const doc = getLegalDocument(locale, documentId);
    return localizedRouteMetadata(locale, doc.path, doc.title, doc.description);
  }

  async function Page({ params }: { params: Promise<{ locale: string }> }) {
    const { locale } = await params;
    if (!isLocale(locale)) notFound();
    const doc = getLegalDocument(locale, documentId);
    const siblings = [
      { id: "mentions" as const, href: `/${locale}/mentions-legales` },
      { id: "confidentialite" as const, href: `/${locale}/confidentialite` },
      { id: "conditions" as const, href: `/${locale}/conditions` },
      { id: "cookies" as const, href: `/${locale}/cookies` },
    ];
    const table = locale === "ar"
      ? [
          ["بيانات الهوية والاتصال", "إنشاء حسابكم وإدارته والتواصل مع ماتريسيا", "طوال العلاقة ومع ماتريسيا وللمدة التي يقتضيها القانون", "الوصول والتصحيح والحذف والاعتراض وقابلية النقل"],
          ["بيانات الاستخدام", "ضمان حسن سير المنصة وتحسين الخدمات", "للمدة اللازمة للأغراض المذكورة", "الوصول والتصحيح والاعتراض"],
          ["بيانات التواصل", "الرد على طلباتكم ومرافقتكم", "للمدة اللازمة لمتابعة التبادلات", "الوصول والتصحيح والحذف"],
          ["بيانات التفضيلات", "إدارة اختياراتكم (ملفات تعريف الارتباط والتواصل)", "طوال مدة حفظ التفضيلات", "الوصول والتصحيح والاعتراض"],
        ]
      : [
          ["Données d’identification et de contact", "Créer et gérer votre compte, communiquer avec Matricia et vous accompagner", "Pendant la durée de votre relation avec Matricia et le temps nécessaire au regard de la loi", "Accès, rectification, suppression, opposition, portabilité (selon les cas prévus par la loi)"],
          ["Données d’utilisation", "Assurer le bon fonctionnement de la plateforme, améliorer nos services", "Pendant la durée nécessaire aux finalités décrites", "Accès, rectification, opposition"],
          ["Données de communication", "Répondre à vos demandes, vous accompagner", "Pendant la durée nécessaire au suivi de nos échanges", "Accès, rectification, suppression"],
          ["Données relatives aux préférences", "Gérer vos choix (cookies et communications)", "Pendant la durée de conservation des préférences", "Accès, rectification, opposition"],
        ];

    return (
      <main id="contenu-principal" className="public-page px-4 py-12 text-[#1a2340] sm:px-6 sm:py-16" dir={locale === "ar" ? "rtl" : "ltr"}>
        <div className="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[240px_minmax(0,1fr)]">
          <nav aria-label={locale === "ar" ? "وثائق قانونية" : "Informations légales"} className="public-legal-nav h-fit rounded-2xl border border-[#eadfce] bg-white p-3">
            <p className="px-3 pb-2 text-sm font-semibold text-[#1a2340]">{locale === "ar" ? "المعلومات القانونية والسرية" : "Informations légales et confidentialité"}</p>
            {siblings.map((item) => {
              const label = getLegalDocument(locale, item.id).title;
              return <Link key={item.id} href={item.href} aria-current={item.id === documentId ? "page" : undefined}>{label}</Link>;
            })}
            <Link href={`/${locale}/confidentialite#securite`}>{locale === "ar" ? "الأمن والبيانات" : "Sécurité et données"}</Link>
            <Link href={`/${locale}/contact`}>{locale === "ar" ? "اتصل بنا" : "Nous contacter"}</Link>
          </nav>
          <article>
            <p className="journey-eyebrow">{locale === "ar" ? "ثقة وشفافية" : "Confiance et transparence"}</p>
            <h1 className="mt-3">{doc.title}</h1>
            <p className="mt-4 text-sm text-slate-500">{locale === "ar" ? `آخر تحديث: ${doc.updated}` : `Date de mise à jour : ${doc.updated}`}</p>
            <p className="mt-6 text-lg leading-8 text-slate-600">{doc.description}</p>
            {documentId === "confidentialite" ? (
              <div id="securite" className="mt-8 overflow-x-auto rounded-2xl border border-[#eadfce] bg-white">
                <table className="min-w-full text-sm">
                  <thead className="bg-[#fbf6ea] text-start">
                    <tr>
                      {(locale === "ar" ? ["فئة البيانات", "غاية المعالجة", "مدة الحفظ", "حقوقكم"] : ["Catégorie de données", "Finalité du traitement", "Durée de conservation", "Vos droits"]).map((heading) => (
                        <th key={heading} className="px-4 py-3 font-semibold">{heading}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {table.map((row) => (
                      <tr key={row[0]} className="border-t border-[#eadfce] align-top">
                        {row.map((cell) => <td key={cell} className="px-4 py-3 leading-6 text-slate-700">{cell}</td>)}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : null}
            {documentId === "cookies" ? <CookiePreferences locale={locale} /> : null}
            <div className="mt-10 space-y-10">
              {doc.sections.map((section) => (
                <section key={section.heading}>
                  <h2 className="text-2xl font-semibold text-[#1a2340]">{section.heading}</h2>
                  {section.paragraphs.map((paragraph) => (
                    <p key={paragraph.slice(0, 48)} className="mt-4 leading-7 text-slate-700">{paragraph}</p>
                  ))}
                </section>
              ))}
            </div>
            <div className="mt-10 grid gap-4 sm:grid-cols-2">
              <Link href={`/${locale}/contact`} className="public-card no-underline">
                <h2>{locale === "ar" ? "ممارسة حقوقي" : "Exercer mes droits"}</h2>
                <p className="public-muted mt-2">{locale === "ar" ? "لكل طلب مرتبط ببياناتكم الشخصية، اتصلوا بفريقنا." : "Pour toute demande liée à vos données personnelles, contactez notre équipe."}</p>
                <span className="journey-known mt-3">{locale === "ar" ? "ممارسة حقوقي" : "Exercer mes droits"}</span>
              </Link>
              <Link href={`/${locale}/cookies`} className="public-card no-underline">
                <h2>{locale === "ar" ? "إدارة تفضيلاتي" : "Gérer mes préférences"}</h2>
                <p className="public-muted mt-2">{locale === "ar" ? "خصّصوا اختياراتكم المتعلقة بملفات تعريف الارتباط والتواصل." : "Personnalisez vos choix en matière de cookies et de communications."}</p>
                <span className="journey-known mt-3">{locale === "ar" ? "إدارة تفضيلاتي" : "Gérer mes préférences"}</span>
              </Link>
            </div>
            <aside className="mt-10 rounded-2xl border border-[#eadfce] bg-white p-5">
              <h2 className="text-lg font-semibold">{locale === "ar" ? "الوصول إلى الوثائق" : "Accès aux documents"}</h2>
              <p className="public-muted mt-2">{locale === "ar" ? "كل وثيقة متاحة بالفرنسية والعربية." : "Chaque document est disponible en français et en arabe."}</p>
              <nav className="mt-3 flex flex-wrap gap-3 text-sm" aria-label={locale === "ar" ? "الوثائق القانونية" : "Documents légaux"}>
                {siblings.flatMap((item) => {
                  const title = getLegalDocument(locale, item.id).title;
                  const path = item.href.replace(`/${locale}`, "");
                  return [
                    <Link key={`${item.id}-fr`} href={`/fr${path}`}>{title} (FR)</Link>,
                    <Link key={`${item.id}-ar`} href={`/ar${path}`}>{title} (AR)</Link>,
                  ];
                })}
              </nav>
            </aside>
          </article>
        </div>
      </main>
    );
  }

  return { generateMetadata, Page };
}
