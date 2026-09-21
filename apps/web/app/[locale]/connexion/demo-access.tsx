import { connectDemoPersona } from "./demo-actions";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const personas = ["client", "provider", "franchise", "admin"] as const;

const copy = {
  fr: {
    title: "Explorer les espaces de démonstration",
    client: "Voir le tableau de bord Client",
    provider: "Voir le tableau de bord Prestataire",
    franchise: "Voir l’espace Franchisé",
    admin: "Voir le tableau de bord Admin",
  },
  ar: {
    title: "استكشف مساحات العرض",
    client: "عرض لوحة تحكم العميل",
    provider: "عرض لوحة تحكم مقدم الخدمات",
    franchise: "عرض فضاء صاحب الامتياز",
    admin: "عرض لوحة تحكم الإدارة",
  },
} satisfies Record<Locale, { title: string } & Record<(typeof personas)[number], string>>;

export function DemoAccess({ locale }: { locale: Locale }) {
  const messages = copy[locale];
  return (
    <section className="mt-7 rounded-2xl border border-blue-200 bg-blue-50 p-4" aria-labelledby="demo-access-title">
      <h2 id="demo-access-title" className="text-sm font-semibold text-blue-950">
        {messages.title}
      </h2>
      <div className="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
        {personas.map((persona) => (
          <form action={connectDemoPersona} key={persona}>
            <input type="hidden" name="locale" value={locale} />
            <input type="hidden" name="persona" value={persona} />
            <button
              type="submit"
              className="min-h-11 w-full rounded-lg bg-blue-700 px-3 py-2 text-sm font-semibold text-white hover:bg-blue-800 focus-visible:outline focus-visible:outline-3 focus-visible:outline-offset-2 focus-visible:outline-blue-700"
            >
              {messages[persona]}
            </button>
          </form>
        ))}
      </div>
    </section>
  );
}
