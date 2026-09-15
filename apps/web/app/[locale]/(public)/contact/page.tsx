import { ArrowUpRight, ClipboardPenLine, LockKeyhole, ScanSearch } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { buttonVariants } from "@/components/ui/button";
import { isLocale } from "@/lib/i18n/locale";
import { cn } from "@/lib/utils";
import { getContactMessages } from "./messages";
import { ContactForm } from "./contact-form";

export default async function ContactPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getContactMessages(locale);
  const paths = [
    { icon: ScanSearch, title: messages.serviceTitle, text: messages.serviceText, action: messages.serviceAction, href: `/${locale}/diagnostic`, primary: true },
    { icon: ClipboardPenLine, title: messages.needTitle, text: messages.needText, action: messages.needAction, href: `/${locale}/besoin`, primary: false },
    { icon: LockKeyhole, title: messages.accountTitle, text: messages.accountText, action: messages.accountAction, href: `/${locale}/connexion`, primary: false },
  ];

  return <main id="contenu-principal" tabIndex={-1} className="bg-[#f7f9fc] text-[#14213d]">
    <section className="border-b border-slate-200 px-4 py-16 sm:px-6 sm:py-24 lg:px-8"><div className="mx-auto max-w-6xl"><p className="text-sm font-semibold uppercase tracking-[0.16em] text-blue-700 rtl:tracking-normal">{messages.eyebrow}</p><h1 className="mt-5 max-w-4xl text-4xl font-semibold leading-[1.08] tracking-[-0.035em] text-balance sm:text-6xl rtl:tracking-normal">{messages.title}</h1><p className="mt-6 max-w-3xl text-lg leading-8 text-slate-600">{messages.description}</p></div></section>
    <section className="px-4 py-14 sm:px-6 sm:py-20 lg:px-8" aria-label={messages.title}><div className="mx-auto grid max-w-6xl gap-5 lg:grid-cols-3">{paths.map(({ icon: Icon, title, text, action, href, primary }) => <article key={title} className="flex min-h-80 flex-col rounded-3xl border border-slate-200 bg-white p-7"><span className="grid size-12 place-items-center rounded-2xl bg-blue-50 text-blue-700"><Icon aria-hidden="true" className="size-6" /></span><h2 className="mt-8 text-2xl font-semibold tracking-[-0.02em] text-[#0b1739] rtl:tracking-normal">{title}</h2><p className="mt-3 grow leading-7 text-slate-600">{text}</p><Link href={href} className={cn(buttonVariants({ variant: primary ? "default" : "outline", size: "lg" }), "mt-7 min-h-12 w-full rounded-xl border-slate-400", primary && "bg-blue-700 hover:bg-blue-800")}>{action}<ArrowUpRight aria-hidden="true" className="size-4 rtl:-scale-x-100" /></Link></article>)}</div>
      <ContactForm locale={locale} />
    </section>
  </main>;
}
