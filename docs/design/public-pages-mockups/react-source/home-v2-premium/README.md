# Home Matricia V2 Premium — source React prête pour Cursor

Ce dossier reproduit la maquette `00-home-v2-premium.png` sous forme de composants React/Next.js exploitables. Il est volontairement séparé du code de production afin que Cursor puisse l’intégrer sans écraser la Home actuelle ni les composants partagés.

## Fichiers

- `HomePremium.tsx` : corps complet de la Home.
- `home-premium.module.css` : design desktop, tablette, mobile 360 px, RTL et réduction des animations.
- `home-premium.copy.ts` : contenu typé FR/AR, séparé du JSX.
- `page.example.tsx` : exemple de route Next.js App Router.
- `assets/hero-collaboration.png` : image du Hero.
- `PROMPT_CURSOR.md` : instruction exacte à coller dans Cursor.

## Intégration dans Matricia

1. Copier `assets/hero-collaboration.png` vers `apps/web/public/home-v2/hero-collaboration.png`.
2. Copier les trois fichiers `HomePremium.tsx`, `home-premium.module.css` et `home-premium.copy.ts` dans un dossier dédié, par exemple `apps/web/modules/public/ui/home-premium/`.
3. Remplacer uniquement le contenu de `apps/web/app/[locale]/(public)/page.tsx` par l’adaptation de `page.example.tsx`.
4. Conserver `apps/web/app/[locale]/(public)/layout.tsx` : il contient déjà la navigation publique, le footer, le skip-link et le contexte RTL.
5. Ne pas recréer d’en-tête ou de footer dans `HomePremium.tsx`.

Les routes utilisées sont les routes réelles :

- `/{locale}/diagnostic`
- `/{locale}/fournisseur`
- `/{locale}/besoin`

Le composant utilise seulement `next/image`, `next/link` et `lucide-react`, déjà présents dans le projet.

## Contrôles après intégration

```bash
corepack pnpm --filter @matricia/web typecheck
corepack pnpm --filter @matricia/web lint
corepack pnpm --filter @matricia/web build
```

Vérifier visuellement en FR et AR à 360, 390, 768 et 1440 px. Vérifier aussi les trois CTA, le clavier, le focus, les accordéons FAQ et `prefers-reduced-motion`.

## Référence visuelle

La cible est `../../00-home-v2-premium.png`. Les proportions peuvent varier légèrement selon les polices réellement chargées par le layout public, mais la structure, la palette, les contenus, les CTA et la hiérarchie sont définis ici.
