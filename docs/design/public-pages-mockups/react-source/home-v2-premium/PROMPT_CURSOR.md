# Prompt à coller dans Cursor

Intègre la Home Matricia V2 Premium fournie dans ce dossier dans l’application Next.js existante.

Contraintes obligatoires :

1. Utilise `HomePremium.tsx`, `home-premium.module.css` et `home-premium.copy.ts` comme source de vérité visuelle et fonctionnelle.
2. Copie `assets/hero-collaboration.png` vers `apps/web/public/home-v2/hero-collaboration.png`.
3. Intègre le composant dans `apps/web/app/[locale]/(public)/page.tsx` en réutilisant la validation de locale existante du projet.
4. Conserve intégralement le layout public existant, sa navigation, son footer, son skip-link, ses metadata et son comportement RTL. Ne crée ni second header, ni second footer, ni second `<main>` imbriqué.
5. Ne modifie aucune route métier, action serveur, authentification, base de données ou règle d’autorisation.
6. Les CTA doivent pointer exactement vers `/{locale}/diagnostic`, `/{locale}/fournisseur` et `/{locale}/besoin`.
7. Conserve tous les textes dans la source de copy typée FR/AR ; aucun texte utilisateur ne doit être ajouté directement dans le composant.
8. La page doit rester utilisable à 360, 390, 768 et 1440 px, en français et en arabe RTL, au clavier et avec `prefers-reduced-motion`.
9. N’ajoute pas de chiffres, témoignages, certifications ou promesses commerciales non prouvés.
10. Après intégration, exécute typecheck, lint et build. Corrige uniquement les erreurs causées par cette intégration et fournis le résultat exact des commandes.

Référence visuelle : `docs/design/public-pages-mockups/00-home-v2-premium.png`.
