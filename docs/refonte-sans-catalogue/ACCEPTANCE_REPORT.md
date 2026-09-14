# Acceptance report — refonte sans catalogue

Date : 2026-09-14. Portée : lots 1–2, plus retour OTP sécurisé.

## Couvert

- L’accueil mène en un clic au prédiagnostic, sans catalogue ni connexion.
- Le prédiagnostic comporte sept questions déclaratives, une question principale par écran, retour arrière, stockage local limité à sept jours et effacement explicite.
- La restitution expose au plus trois priorités, le périmètre et les limites ; elle ne produit pas de score global.
- Le besoin direct fonctionne sans diagnostic général.
- Les routes historiques `/[locale]/services` et `/[locale]/services/[code]` conservent l’intention vers le parcours guidé ; un service inconnu reste introuvable.
- Les retours OTP n’acceptent que des chemins locaux du même locale et conservent la destination demandée.
- FR/AR, RTL, mobile 360 px, clavier et scan axe sont couverts sur les parcours publics par le test E2E ciblé.

## Commandes exécutées

| Commande | Résultat |
| --- | --- |
| `corepack pnpm --filter @matricia/web typecheck` | réussi |
| `corepack pnpm --filter @matricia/web lint` | réussi |
| `corepack pnpm exec playwright test tests/e2e/refonte-sans-catalogue-public.spec.ts --workers=2 --reporter=dot` | réussi, 4 tests |
| inspection navigateur local | synthèse du prédiagnostic visible après soumission |

## Limites en cours

Le rattachement atomique du brouillon public après OTP, la conversion en demande préremplie et la reprise du contexte fournisseur restent les travaux suivants. Aucune migration de cette refonte n’a encore été appliquée à Supabase, et aucun déploiement de production n’a été déclenché.
