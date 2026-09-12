import type { ReactNode } from "react";

export function PageHero({ eyebrow, title, description, children }: { eyebrow: string; title: string; description: string; children?: ReactNode }) {
  return <section className="relative isolate overflow-hidden border-b bg-primary px-4 py-16 text-primary-foreground sm:px-6 sm:py-24 lg:px-8"><div aria-hidden="true" className="absolute -end-24 -top-28 size-80 rounded-full bg-white/10 blur-3xl" /><div aria-hidden="true" className="absolute -bottom-32 start-1/3 size-72 rounded-full bg-accent/25 blur-3xl" /><div className="relative mx-auto max-w-7xl"><p className="text-sm font-semibold uppercase tracking-[0.18em] text-white/70">{eyebrow}</p><h1 className="mt-4 max-w-4xl text-4xl font-semibold tracking-tight text-balance sm:text-5xl lg:text-6xl">{title}</h1><p className="mt-6 max-w-3xl text-lg leading-8 text-white/75 sm:text-xl">{description}</p>{children}</div></section>;
}

export function SectionHeading({ eyebrow, title, description }: { eyebrow?: string; title: string; description?: string }) {
  return <div className="max-w-3xl">{eyebrow ? <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">{eyebrow}</p> : null}<h2 className="mt-2 text-3xl font-semibold tracking-tight text-balance sm:text-4xl">{title}</h2>{description ? <p className="mt-4 text-lg leading-8 text-muted-foreground">{description}</p> : null}</div>;
}

export function NumberedCard({ number, title, description }: { number: string; title: string; description: string }) {
  return <article className="h-full rounded-2xl border bg-card p-6 shadow-sm"><span aria-hidden="true" className="grid size-10 place-items-center rounded-xl bg-accent text-sm font-bold text-accent-foreground">{number}</span><h3 className="mt-5 text-xl font-semibold">{title}</h3><p className="mt-3 leading-7 text-muted-foreground">{description}</p></article>;
}
