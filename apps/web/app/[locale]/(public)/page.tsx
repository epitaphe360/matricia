import Link from "next/link";
import { ArrowRight, CheckCircle2, Lightbulb, MessageSquareText } from "lucide-react";
import { notFound } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { getPublicJourneyCopy } from "@/lib/public-journey/copy";

export default async function PublicHomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params; if (!isLocale(locale)) notFound(); const c = getPublicJourneyCopy(locale).home;
  return <main id="contenu-principal" className="journey-home">
    <section className="journey-home-hero"><div><p className="journey-eyebrow">{c.eyebrow}</p><h1>{c.title}</h1><p>{c.intro}</p><div className="journey-actions"><Link className="journey-primary" href={"/" + locale + "/diagnostic"}>{c.start}<ArrowRight size={18} aria-hidden="true" /></Link><Link className="journey-secondary" href={"/" + locale + "/fournisseur"}>{c.provider}</Link></div><Link className="journey-known" href={"/" + locale + "/besoin"}>{c.known}<ArrowRight size={16} aria-hidden="true" /></Link><small>{c.note}</small></div><aside aria-label={c.example}><span>{c.example}</span><Lightbulb aria-hidden="true" size={26}/><h2>{c.exampleTitle}</h2><p>{c.exampleProblem}</p><strong>{c.exampleAction}</strong></aside></section>
    <section id="comment-ca-marche" className="journey-home-section"><p className="journey-eyebrow">{c.stepsTitle}</p><div className="journey-steps">{c.steps.map(([title, text], index) => <article key={title}><span>0{index + 1}</span><h2>{title}</h2><p>{text}</p></article>)}</div></section>
    <section className="journey-home-section journey-home-example"><div><p className="journey-eyebrow">{c.example}</p><h2>{c.exampleTitle}</h2><p>{c.exampleProblem}</p><strong>{c.exampleAction}</strong></div><div className="journey-example-lines"><span /><span /><span /></div></section>
    <section id="fournisseurs" className="journey-home-provider"><MessageSquareText aria-hidden="true" size={34}/><p className="journey-eyebrow">{c.provider}</p><h2>{c.providerTitle}</h2><p>{c.providerText}</p><Link className="journey-primary" href={"/" + locale + "/fournisseur"}>{c.providerAction}<ArrowRight size={18} aria-hidden="true" /></Link></section>
    <section className="journey-home-section"><p className="journey-eyebrow">{c.faqTitle}</p><div className="journey-faq">{c.faqs.map(([question, answer]) => <details key={question}><summary>{question}<CheckCircle2 aria-hidden="true" size={18}/></summary><p>{answer}</p></details>)}</div><Link className="journey-primary" href={"/" + locale + "/diagnostic"}>{c.start}<ArrowRight size={18} aria-hidden="true" /></Link></section>
  </main>;
}
