import {
  Activity,
  AlertTriangle,
  Building2,
  CheckCircle2,
  ClipboardCheck,
  FileText,
  LayoutDashboard,
  ShieldCheck,
  Users,
} from "lucide-react";

import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

const navigation = [
  { label: "Vue d’ensemble", href: "#overview", icon: LayoutDashboard },
  { label: "Organisations", href: "#organizations", icon: Building2 },
  { label: "Conformité", href: "#compliance", icon: ClipboardCheck },
  { label: "Prestataires", href: "#providers", icon: Users },
  { label: "Documents", href: "#documents", icon: FileText },
];

const metrics = [
  { label: "Santé globale", value: "84 %", note: "+6 pts ce mois", icon: Activity },
  { label: "Actions prioritaires", value: "12", note: "4 à traiter aujourd’hui", icon: AlertTriangle },
  { label: "Contrôles conformes", value: "37/42", note: "5 preuves attendues", icon: ShieldCheck },
];

const actions = [
  { title: "Registre fiscal à compléter", scope: "Finance · Maroc", due: "Aujourd’hui", tone: "urgent" },
  { title: "Valider les pièces du prestataire", scope: "Qualification · IT", due: "Demain", tone: "review" },
  { title: "Revoir le plan d’action QHSE", scope: "Diagnostic · Site Rabat", due: "12 sept.", tone: "normal" },
];

export default function Home() {
  return (
    <SidebarProvider>
      <Sidebar collapsible="offcanvas" className="border-r border-slate-200">
        <SidebarHeader className="border-b border-slate-200 px-5 py-5">
          <div className="flex items-center gap-3">
            <div className="grid size-10 place-items-center rounded-xl bg-primary text-sm font-bold text-primary-foreground">M</div>
            <div>
              <p className="text-base font-bold tracking-tight">Matricia</p>
              <p className="text-xs text-muted-foreground">Pilotage d’entreprise</p>
            </div>
          </div>
        </SidebarHeader>
        <SidebarContent className="px-2 py-4">
          <SidebarGroup>
            <SidebarGroupLabel>ESPACE CLIENT</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {navigation.map((item, index) => (
                  <SidebarMenuItem key={item.label}>
                    <SidebarMenuButton asChild isActive={index === 0} tooltip={item.label}>
                      <a href={item.href}>
                        <item.icon aria-hidden="true" />
                        <span>{item.label}</span>
                      </a>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
        <div className="m-4 rounded-xl border border-blue-100 bg-blue-50 p-4 text-sm">
          <p className="font-semibold text-primary">Essai actif</p>
          <p className="mt-1 text-xs leading-5 text-slate-600">26 jours restants pour explorer l’espace Matricia.</p>
        </div>
      </Sidebar>

      <SidebarInset className="min-w-0 bg-background">
        <header className="sticky top-0 z-10 flex min-h-16 items-center justify-between border-b border-slate-200 bg-white/95 px-4 backdrop-blur sm:px-7">
          <div className="flex items-center gap-3">
            <SidebarTrigger aria-label="Ouvrir la navigation" />
            <span className="text-sm text-muted-foreground">Organisation</span>
            <span aria-hidden="true" className="text-slate-300">/</span>
            <span className="text-sm font-semibold">NEOXA Conseil</span>
          </div>
          <div className="hidden items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-xs font-semibold text-emerald-800 sm:flex">
            <CheckCircle2 className="size-3.5" aria-hidden="true" /> Données sécurisées
          </div>
        </header>

        <main id="overview" className="mx-auto w-full max-w-7xl px-4 py-7 sm:px-7 lg:py-10">
          <div className="mb-8 flex flex-col gap-2">
            <p className="text-sm font-semibold text-blue-700">Jeudi 10 septembre 2026</p>
            <h1 className="text-2xl font-bold tracking-tight text-slate-950 sm:text-3xl">Bonjour Jalil, voici vos priorités.</h1>
            <p className="max-w-2xl text-base leading-7 text-muted-foreground">Suivez la conformité, les demandes et les actions qui nécessitent votre attention.</p>
          </div>

          <section aria-labelledby="metrics-title">
            <h2 id="metrics-title" className="sr-only">Indicateurs principaux</h2>
            <div className="grid gap-4 md:grid-cols-3">
              {metrics.map((metric) => (
                <Card key={metric.label} className="gap-4 border-slate-200 py-5 shadow-[0_8px_30px_rgb(15_23_42/0.05)]">
                  <CardHeader className="grid grid-cols-[1fr_auto] px-5">
                    <div>
                      <CardDescription>{metric.label}</CardDescription>
                      <CardTitle className="mt-2 text-3xl text-slate-950">{metric.value}</CardTitle>
                    </div>
                    <div className="grid size-10 place-items-center rounded-xl bg-blue-50 text-blue-700"><metric.icon aria-hidden="true" className="size-5" /></div>
                  </CardHeader>
                  <CardContent className="px-5 text-sm text-slate-600">{metric.note}</CardContent>
                </Card>
              ))}
            </div>
          </section>

          <section className="mt-7 grid gap-6 lg:grid-cols-[minmax(0,1.45fr)_minmax(280px,0.75fr)]">
            <Card className="gap-0 overflow-hidden border-slate-200 py-0 shadow-[0_8px_30px_rgb(15_23_42/0.05)]">
              <CardHeader className="border-b border-slate-100 px-5 py-5 sm:px-6">
                <CardTitle>À traiter</CardTitle>
                <CardDescription>Les actions classées par priorité et échéance.</CardDescription>
              </CardHeader>
              <CardContent className="divide-y divide-slate-100 px-0">
                {actions.map((action) => (
                  <article key={action.title} className="flex flex-col gap-3 px-5 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
                    <div className="flex items-start gap-3">
                      <span className={`mt-1.5 size-2.5 shrink-0 rounded-full ${action.tone === "urgent" ? "bg-rose-500" : action.tone === "review" ? "bg-amber-500" : "bg-blue-600"}`} aria-hidden="true" />
                      <div>
                        <h3 className="font-semibold text-slate-900">{action.title}</h3>
                        <p className="mt-1 text-sm text-muted-foreground">{action.scope}</p>
                      </div>
                    </div>
                    <p className="pl-5 text-sm font-medium text-slate-700 sm:pl-0">{action.due}</p>
                  </article>
                ))}
              </CardContent>
            </Card>

            <Card className="border-0 bg-primary py-6 text-primary-foreground shadow-[0_14px_40px_rgb(11_45_79/0.18)]">
              <CardHeader className="px-6">
                <div className="mb-4 grid size-11 place-items-center rounded-xl bg-white/10"><ShieldCheck className="size-5" aria-hidden="true" /></div>
                <CardTitle className="text-xl">Prochaine étape</CardTitle>
                <CardDescription className="text-blue-100">Complétez votre diagnostic Finance pour obtenir un plan d’action priorisé.</CardDescription>
              </CardHeader>
              <CardContent className="px-6">
                <div className="h-2 overflow-hidden rounded-full bg-white/15"><div className="h-full w-3/4 rounded-full bg-blue-400" /></div>
                <p className="mt-3 text-sm font-medium text-blue-50">75 % complété</p>
              </CardContent>
            </Card>
          </section>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
