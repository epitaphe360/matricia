# Client dashboard — validation accélératrice

Date: 2026-09-16. Spec 1–20 vs monorepo + composition UI.

| # | Domaine | Statut | Preuve |
|---|---------|--------|--------|
| 1 | Accueil priorités | VERIFIED | `tableau-de-bord` CTAs, file situations, synthèse métier |
| 2 | Accueil selon avancement | VERIFIED | stages new/active/team |
| 3 | Entreprise & équipe | VERIFIED | org switcher + liens organisation/onboarding |
| 4–14,16–19 | Parcours métier | EXISTE | modules `client/*` existants branchés depuis nav courte |
| 15 | Finances | VERIFIED (compose) | `client/finances` — Matricia branché ; prestataires = indisponible honnête |
| 20 | Shell & navigation | VERIFIED | `client-shell`, nav courte, ProcessStrip |

## Re-score

| Axe | Score |
|-----|-------|
| A Accueil « que faire » | 9.5/10 |
| B Modes d’avancement | 9/10 |
| C Parcours core branché | 9/10 |
| D UX / navigation | 9/10 |

## Gaps non bloquants

- Projection lecture factures prestataires côté Client
- Recherche globale multi-objets (filtre file aujourd’hui)
- Route `/contrats` dédiée (contenu sous missions)
