# Carte d’exécution V1

| Phase | Portée | Gate de sortie |
|---|---|---|
| 00 | Reconnaissance, mémoire, matrices, ownership, architecture, threat model | Inventaire, architecture, ownership et matrices initialisés |
| 01 | Contrats écrans/formulaires/permissions/API/événements/notifications/state machines | `pnpm spec:validate` vert |
| 02 | Monorepo, CI, design tokens, configuration, observabilité | install, lint, typecheck, test et build minimaux verts |
| 03 | PostgreSQL, migrations, contraintes, RLS, audit, Outbox, ledgers | reset DB, migrations et tests SQL/RLS verts |
| 04 | Auth OTP, sessions, organisation unique multi-rôles | rattachement et rôles Client/Provider/Franchisé prouvés |
| 05 | Onboarding et conformité Client | parcours anomalies/questions/résultat et trial complet |
| 06 | 10 bibliothèques, 200 services, 6 000 questions, Builders | bibliothèque publiable/simulable sans code spécifique |
| 07 | Diagnostics, scoring, anomalies, recommandations, opportunités | diagnostic réel vers opportunité exploitable |
| 08 | Trial, plans, paiements, Boxes, avantages, crédits | Trial→Gold→Box→achat/consommation avec ledgers |
| 09 | Validation et qualification Provider | société/service/capacité/restrictions prouvés |
| 10 | Franchise, CRM, gouvernance et performance | IT Hatim 50/50 bénéfice et fee zéro ; autres 50/25/25 ; audit/plan correctif |
| 11 | Besoins, matching, RFQ, questions, devis | panel éligible, offres isolées, comparaison/sélection |
| 12 | Contrats, signatures, missions, jalons, livraisons | mission normale avec preuves et réception |
| 13 | Litiges, pénalités, réaffectation | hors périmètre/non-conformité et idempotence prouvés |
| 14 | Fiscalité Maroc, facture Provider, recouvrement | règles fiscales versionnées et pipeline mensuel automatique testé |
| 15 | Revenus franchise, allocations, P&L | répartitions correctes, coûts traçables, écritures équilibrées |
| 16 | SKU, contrats-cadres et pools volume | réservation, consommation et rebate prouvés |
| 17 | Admin, automatisations, notifications, reporting | command center et files opérationnelles complets |
| 18 | Seeds des dix domaines, FR/AR, Marketing Autopilot | seuils catalogue, marketing V1, traductions et zéro placeholder |
| 19 | Hardening, audits, clean clone, staging | Definition of Done intégrale et audits indépendants signés |

Gate 0 transversal : aucun développement métier majeur sans contrats atomiques complets pour la phase. Production reste exclue sans autorisation explicite et sans gate de production.
