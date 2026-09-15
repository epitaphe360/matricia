# Matricia — Rapport d’acceptation design premium

Date : 2026-09-14

## Audit avant modification

Les captures réelles de la Home montraient une hiérarchie trop plate, des compositions répétées et un rendu mobile encore proche d’une colonne bureau réduite. Le produit manquait d’un aperçu concret permettant de comprendre immédiatement le passage d’une réponse à une action.

Captures navigateur avant, page complète :

- `screenshots/before/home-fr-1440.png` — 1440 × 1000
- `screenshots/before/home-fr-768.png` — 768 × 1024
- `screenshots/before/home-fr-390.png` — 390 × 844
- `screenshots/before/home-ar-360.png` — contrôle RTL à 360 px

## Résultat vérifié

- L’activité et le CTA principal sont visibles dès le premier écran.
- L’aperçu produit est explicitement illustratif et composé de HTML/SVG accessibles.
- Aucun catalogue public, faux score, faux avis ou étape métier n’a été ajouté.
- FR et AR ont été contrôlés sur Home, diagnostic, besoin, fournisseur et connexion.
- Audit indépendant : 40 combinaisons route/langue/largeur servies en HTTP 200, sans débordement horizontal, avec une seule H1 et zéro violation Axe A/AA automatique.
- Le diagnostic conserve l’étape et les réponses lors du changement de langue ; le besoin conserve la saisie après navigation.
- Les choix simples exposent `radiogroup`/`radio`/`aria-checked`; les champs libres sont reliés à leur question.
- Menu mobile : état `aria-expanded`, fermeture par `Escape` et retour du focus au déclencheur.

## Captures après

Captures réelles depuis le build Next.js de production local :

- `screenshots/after/home-fr-1440.png`
- `screenshots/after/home-fr-768.png`
- `screenshots/after/home-fr-390.png`
- `screenshots/after/home-ar-360.png`
- `screenshots/after/diagnostic-fr-1440.png`
- `screenshots/after/diagnostic-ar-390.png`
- `screenshots/after/besoin-fr-390.png`
- `screenshots/after/fournisseur-fr-1440.png`
- `screenshots/after/connexion-ar-390.png`
- `screenshots/after/inscription-fr-390.png`

La commande reproductible est `node scripts/capture-design-premium.mjs http://localhost:5174` après démarrage du build local.

## Gates exécutés

- `corepack pnpm --filter @matricia/web lint` — réussi, 0 erreur.
- `corepack pnpm --filter @matricia/web typecheck` — réussi.
- `corepack pnpm --filter @matricia/web build` — réussi, Next.js 16.3.3.
- `corepack pnpm --filter @matricia/web test` — 151 fichiers, 627 tests réussis.
- `corepack pnpm --filter @matricia/ui test` — 1 fichier, 4 tests réussis.
- Playwright ciblé — 26 tests réussis en 34,7 s sur profils desktop et mobile 360.
- Les tests ciblés couvrent 360, 390, 768 et 1440 px, FR/AR, huit routes publiques, Axe A/AA, overflow, H1, menu clavier, contexte de langue et sémantique des champs.

## Limites

Les espaces connectés n’ont pas été inspectés visuellement : aucun compte de test autorisé ni jeu de données non réel n’a été fourni pour cette passe. Les tokens partagés ont été validés par le build et les tests, mais aucune conformité WCAG totale ni performance terrain n’est proclamée sur la seule base des contrôles automatiques.

Cette intervention n’a déclenché ni déploiement, ni courriel, ni paiement, ni consultation réelle, et n’a modifié aucune migration ou politique de sécurité.
