# Matricia — Design premium

## Direction

L’interface suit une expression B2B moderne et professionnelle : fond clair, hiérarchie typographique forte, technologie discrète et une seule bande bleu nuit. La signature visuelle **Réponse → Priorité → Action** est réservée à l’aperçu produit et au fonctionnement, sans faux score ni promesse commerciale.

## Tokens

Les valeurs restent centralisées dans `packages/ui/src/tokens.css` et `packages/ui/src/tokens.ts` :

- fond `#F7F9FC`, surface `#FFFFFF`, surface légère `#EFF6FF` ;
- marque `#0B1739`, texte `#14213D`, texte secondaire `#475569` ;
- action `#1D4ED8`, survol `#1E40AF`, focus `#1D4ED8` ;
- séparation `#E2E8F0`, bronze décoratif `#B49A6C` ;
- rayons 8, 12 et 16 px, grandes compositions à 24 px ;
- transitions CSS courtes et neutralisées avec `prefers-reduced-motion`.

## Composants et comportements

- Navigation publique courte, CTA dominant, langue conservant route et paramètres, menu mobile piloté par bouton et fermeture par `Escape`.
- Home en cinq sections : hero, aperçu produit, fonctionnement, valeur, fournisseurs puis FAQ/CTA dans la dernière section.
- Tunnels diagnostic et besoin centrés, une question à la fois, états sélectionnés avec couleur et icône, champs nommés pour les technologies d’assistance.
- Brouillons publics conservés sept jours dans le navigateur ; le changement FR/AR garde l’étape et traduit les choix connus.
- Résultat diagnostic structuré par périmètre, limites et priorités typées : déclaré, risque potentiel, information à vérifier ou opportunité.
- Fournisseur en quatre étapes lisibles, sans promesse de mission ni catalogue public.
- Connexion et pages éditoriales harmonisées avec la continuité du parcours et des états OTP explicites.

## Routes concernées

- `/{locale}`
- `/{locale}/diagnostic`
- `/{locale}/besoin`
- `/{locale}/fournisseur`
- `/{locale}/connexion`
- `/{locale}/a-propos`
- `/{locale}/franchise`
- `/{locale}/contact`

Les anciennes routes publiques `/services` continuent de rediriger vers le besoin précis. Aucun catalogue, migration, prix, contrat, permission ou flux financier n’a été modifié.
