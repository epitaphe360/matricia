import Link from "next/link";
import { notFound } from "next/navigation";
import { isLocale } from "@/modules/shared/lib/i18n/locale";
import { FranchiseApplicationForm } from "../../(public)/franchise/franchise-application-form";
import { PublicPhoto } from "@/modules/public/ui/site/public-photo";
import { PublicFooter } from "@/modules/public/ui/site/public-footer";
import { PublicNavigation } from "@/modules/public/ui/site/public-navigation";
import { getPublicMessages } from "../../(public)/messages";
import "../../(public)/experience.css";

export default async function FranchiseCandidaturePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const fr = locale === "fr";
  const steps = fr
    ? [
        ["Candidature", "Vous nous transmettez votre demande en ligne."],
        ["Évaluation", "Notre équipe étudie votre profil et votre projet."],
        ["Périmètre et bibliothèque", "Nous définissons ensemble le territoire et la bibliothèque envisagés."],
        ["Validation", "Le projet est soumis à une validation interne."],
        ["Contrat", "Une fois validé, un contrat est établi dans un cadre clair et durable."],
        ["Pilotage", "Vous êtes accompagné(e) dans le lancement et le suivi de votre bibliothèque."],
      ]
    : [
        ["الترشيح", "ترسلون طلبكم عبر الإنترنت."],
        ["التقييم", "تدرس فرقنا ملفكم ومشروعكم."],
        ["النطاق والمكتبة", "نحدد معاً الإقليم والمكتبة المتوخاة."],
        ["المصادقة", "يُعرض المشروع على مصادقة داخلية."],
        ["العقد", "بعد المصادقة يُبرم عقد في إطار واضح ومستدام."],
        ["القيادة", "تُرافقون في الإطلاق ومتابعة مكتبتكم."],
      ];

  return (
    <div dir={locale === "ar" ? "rtl" : "ltr"} className="public-root flex min-h-dvh flex-col text-[#1a2340]">
      <a href="#contenu-principal" className="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:start-2 z-50 bg-white text-slate-950 p-3">{getPublicMessages(locale).common.skipToContent}</a>
      <PublicNavigation locale={locale} />
      <main id="contenu-principal" className="public-page flex-1 pb-16">
        <section className="public-wrap grid gap-10 py-14 lg:grid-cols-[1.1fr_.9fr] lg:items-center">
          <div>
            <p className="journey-eyebrow">{fr ? "Franchise Matricia" : "امتياز ماتريسيا"}</p>
            <h1>{fr ? "Développez une bibliothèque Matricia dans votre territoire" : "طوّروا مكتبة ماتريسيا في إقليمكم"}</h1>
            <p className="public-lead mt-4">
              {fr
                ? "Rejoignez une initiative culturelle et éducative au service des professionnels marocains, et contribuez à faire rayonner le savoir dans votre région."
                : "انضموا إلى مبادرة ثقافية وتعليمية في خدمة المهنيين المغاربة، وساهموا في إشعاع المعرفة في جهتكم."}
            </p>
          </div>
          <PublicPhoto scene="terrace" caption={fr ? "Des territoires plus forts par le savoir" : "أقاليم أقوى بالمعرفة"} />
        </section>
        <section className="public-wrap grid gap-8 lg:grid-cols-[.85fr_1.15fr_.8fr]">
          <PublicPhoto scene="zellige" caption={fr ? "Des bibliothèques au service des talents de nos régions" : "مكتبات في خدمة مواهب جهاتنا"} />
          <div id="candidature-franchise">
            <FranchiseApplicationForm locale={locale} />
          </div>
          <aside className="journey-rail">
            <h2>{fr ? "Votre candidature" : "ترشيحكم"}</h2>
            <ol>
              {steps.map(([title, text], index) => (
                <li key={title}>
                  <span>{index + 1}</span>
                  <strong>{title}<br /><span className="font-normal text-slate-600">{text}</span></strong>
                </li>
              ))}
            </ol>
            <p className="mt-6 text-sm leading-6 text-slate-600">
              {fr
                ? "La sélection, le territoire et la bibliothèque sont soumis à une étude et à une approbation de l’équipe Matricia. Déposer une candidature ne garantit pas son acceptation."
                : "يخضع الاختيار والإقليم والمكتبة لدراسة وموافقة فريق ماتريسيا. إيداع ترشيح لا يضمن القبول."}
            </p>
          </aside>
        </section>
        <p className="public-wrap mt-6">
          <Link className="journey-known" href={`/${locale}/connexion?next=${encodeURIComponent(`/${locale}/franchise/candidature`)}`}>
            {fr ? "J’ai déjà commencé une candidature" : "لقد بدأت ترشيحاً بالفعل"}
          </Link>
        </p>
      </main>
      <PublicFooter locale={locale} />
    </div>
  );
}
