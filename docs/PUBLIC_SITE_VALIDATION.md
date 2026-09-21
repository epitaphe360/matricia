# Site public — validation accélératrice

Date: 2026-09-16. Spec 1–14 vs monorepo + composition.

| # | Domaine | Statut | Preuve |
|---|---------|--------|--------|
| 1 | Navigation commune | VERIFIED | `public-navigation` Entreprises/Professionnels/Offres/Franchise + FR/AR preserveQuery |
| 2 | Accueil | VERIFIED | CTAs + 6 étapes + domaines catalogue + FAQ confiance |
| 3 | Prédiagnostic | EXISTE | `prediagnostic-flow` + brouillon local + handoff compte |
| 4 | Besoin précis | EXISTE | `need-flow` étapes + confirmation + états appareil/compte |
| 5 | Entreprises | VERIFIED | `(public)/entreprises` orientation situation |
| 6 | Professionnels | EXISTE | `fournisseur` + taxonomie canonique |
| 7 | Domaines / services | EXISTE | `services` guide + fiches |
| 8 | Offres | EXISTE | `abonnements` plans publiés, pas de débit |
| 9 | Franchise | VERIFIED | présentation + formulaire conditionnel |
| 10 | Contact | VERIFIED | motifs adaptés + confirmation enregistrement réelle |
| 11 | Inscription / connexion | EXISTE | `connexion` dual intent + `next=` handoffs |
| 12 | À propos / légales | VERIFIED | a-propos + mentions / confidentialité / conditions + footer |
| 13 | Listes dynamiques | PARTIEL | taxonomie services/provider ; dépendances domaine→catégorie |
| 14 | Progression / erreurs | EXISTE | flows + états locaux + anti double-submit |

## Re-score

| Axe | Score |
|-----|-------|
| A Orientation publique | 9.5/10 |
| B Parcours avant compte | 9/10 |
| C Handoff sécurisé | 9/10 |
| D Cohérence nav/légal | 9.5/10 |

## Gaps non bloquants

- Branches prédiagnostic encore déclaratives (pas tout le moteur règles catalogue)
- Conversion brouillon→RFQ complète (Lot 3 refonte)
