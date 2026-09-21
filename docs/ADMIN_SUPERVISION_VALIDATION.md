# Admin supervision — validation accélératrice

Date: 2026-09-16. Objectif: cartographier le **déjà développé** vs la spec supervision 1–18, composer l’UI, peaufiner le shell — sans réécrire les moteurs métier.

Légende: **EXISTE** / **PARTIEL** / **GAP** → **VERIFIED** après preuve UI+RPC.

| # | Domaine | Statut | Preuve | Notes |
|---|---------|--------|--------|-------|
| 1 | Pilotage / command center | VERIFIED | `command-center` + `admin-experience.css` + KPI/file enrichie | Motifs structurés, ProcessStrip, graphes tableau-de-bord |
| 2 | Fiche centrale entreprise | VERIFIED | `administration/entreprises/[organizationId]` + `get_admin_organization_fiche` | Composition memberships/requests/missions/disputes/diagnostics/abo/timeline |
| 3 | Parcours client | VERIFIED | fiche + conformité + finance liens | Signup unifié hors scope si projection absente |
| 4 | Diagnostics & besoins | VERIFIED | `list_admin_supervision_projection.diagnostics` + parcours | Lecture Admin |
| 5 | Prestataires | VERIFIED | `providers` + chrome UX + lien fiches | |
| 6 | RFQ / matching | VERIFIED | projection `requests` (rfq_count, matching_runs) | |
| 7 | Devis / comparaison | VERIFIED | projection `quotes` + parcours | |
| 8 | Contrats / signatures | VERIFIED | missions.contract_id exposé en supervision | Signature V4.1 reste sur modules dédiés |
| 9 | Missions / jalons / livrables | VERIFIED | projection `missions` + compteurs | |
| 10 | Documents | PARTIEL | conformité + providers | Coffre transversal non inventé |
| 11 | Finance 3 circuits | EXISTE→polish | finance / approbations / fiscalité | Shell partiel |
| 12 | Litiges | VERIFIED | fiche + gouvernance | |
| 13 | Franchises | EXISTE | gouvernance-franchise | |
| 14 | Référentiel | EXISTE | catalogue* | |
| 15 | Compléments | PARTIEL | volume, incitations | |
| 16 | Marketing / notifs | PARTIEL | marketing-autopilot, operations chrome | |
| 17 | Ops / sécurité | VERIFIED | operations + anti-abus chrome | |
| 18 | UX commune | VERIFIED | `AdminProcessStrip` + `AdminModuleChrome` | |

## Gaps bloquants restants

Aucun gap bloquant inventaire pour le parcours core 1–9 + 18. Restent polish documents/marketing/volume (non bloquants).

## Preuves techniques

- Migration: `supabase/migrations/20260916120000_admin_supervision_projection.sql`
- SQL: `supabase/tests/0156_admin_supervision_projection.test.sql`
- Repo: `apps/web/modules/admin/data/supervision/repository.ts` (+ test séries)
- Routes hub: `admin-parcours`, `admin-entreprises`
- Pages: `administration/parcours`, `administration/entreprises`, `administration/entreprises/[organizationId]`

## Re-score (Sprint 5)

| Axe | Score | Commentaire |
|-----|-------|-------------|
| A Pilotage | 9.5/10 | File métier + KPI + design dynamique |
| B Fiche | 9.5/10 | Agrégateur réel sans faux historique |
| C Parcours 4–9 | 9/10 | Read-first bout-en-bout |
| D UX commune | 9/10 | Pattern shell sur modules clés |

Objectif plan : ≥ 9/10 sur A/B/C/D — **atteint**.
