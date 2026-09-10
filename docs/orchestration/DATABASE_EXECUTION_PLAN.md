# Database Execution Plan — Matricia V1

## Principes d’exécution

- Supabase PostgreSQL/Auth/Storage ; RLS restrictive par défaut.
- Migrations petites, ordonnées et immuables après application ; toute correction distante crée une nouvelle migration.
- Une table exposée active RLS et révoque immédiatement le DML direct dans sa migration de création.
- UUID serveur, `timestamptz` UTC, montants en unités mineures `bigint`, taux en points de base ou décimal exact.
- Les relations tenant sensibles utilisent des FK composites incluant `organization_id`.
- Les données publiées/signées/émises, les ledgers, l’audit et l’Outbox ne sont jamais réécrits.

## Vagues de migrations

| Vague | Contenu | Gate |
|---|---|---|
| DB-00 | Extensions minimales, schémas `private/public`, domaines et références | Reset depuis une base vide |
| DB-01 | Identité, organisations, memberships, rôles, permissions et scopes | Matrice RBAC SQL verte |
| DB-02 | Idempotence, audit append-only, Outbox, delivery et dead-letter | Retry/déduplication verts |
| DB-03 | Ledger financier équilibré et ledger crédits FIFO append-only | Tests propriété et concurrence verts |
| DB-04 | Compliance et documents privés | Tests RLS tenant/Storage verts |
| DB-05 | Bibliothèques, catégories, services, versions et staging catalogue | Import manifeste idempotent |
| DB-06 | Questionnaires, règles, diagnostics, anomalies et opportunités | Version V1 figée après publication |
| DB-07 | Plans, abonnements, avantages, Boxes, packs, achats et réservations | Double consommation impossible |
| DB-08 | Providers, qualifications, capacités et franchises | Exclusivité et scopes prouvés |
| DB-09 | RFQ, matching, devis et feedback | Aucun devis concurrent visible |
| DB-10 | Contrats, signatures, missions, livraisons et avenants | Snapshots et immutabilité prouvés |
| DB-11 | Incidents, décisions, pénalités et réaffectations | Décision atomique/idempotente |
| DB-12 | Moteur fiscal Maroc, commissions, périodes, factures, avoirs, paiements | Numérotation et calcul ligne par ligne |
| DB-13 | Franchise P&L, distributions et contrats volume/pools | Ledger et snapshots économiques verts |
| DB-14 | Notifications, reporting et Marketing Autopilot | Isolation et publication sûre |

Chaque vague métier livre ensemble : schéma et contraintes, RLS, RPC autorisées, index, tests SQL/RLS, puis mise à jour du registre de phase.

## Fonctions privées et RPC

- Autorisation : `is_org_member`, `has_permission`, `has_library_scope`, `has_franchise_scope`.
- Audit/événements : append audit, enqueue, claim `FOR UPDATE SKIP LOCKED`, ack/retry/dead-letter.
- Finance : post journal entry, réserve de numéro, émission facture/avoir, allocation paiement.
- Crédits : grant, reserve, release, consume FIFO, refund, expire.
- Fiscalité : résolution d’une règle à une date et calcul exact ligne par ligne.
- Workflows : publication catalogue/questionnaire, sélection devis, signature, décision de litige, clôture fournisseur, distribution franchise.

Toute RPC sensible vérifie `auth.uid()`, rôle et scope en base, fixe un `search_path` fermé, qualifie ses objets et accepte une clé d’idempotence avec hash du payload.

## Invariants critiques

- ICE actif/vérifié unique sous forme normalisée ; un doublon ouvre rattachement/fusion.
- Une version unique par agrégat et une seule version courante/publiée.
- Un franchisé actif maximum par bibliothèque et territoire.
- Une organisation ne répond jamais à sa propre demande.
- Écriture financière équilibrée par devise avant commit ; aucun `UPDATE/DELETE` de ledger.
- Numéro de facture réservé atomiquement, continu et jamais réutilisé.
- Paiement alloué sous verrou sans dépasser paiement ni solde exigible.
- `NON_COMPLIANT_CONFIRMED` ne produit qu’une pénalité, commission et réaffectation malgré les retries.
- TVA, commission et partage proviennent de règles datées/versionnées, jamais du navigateur.

## RLS et indexation

- Policies combinant tenant, membership, permission et scope bibliothèque/franchise.
- Les admins globaux sont vérifiés en base ; les auditeurs utilisent des vues pseudonymisées.
- Buckets privés et URL signées courtes après contrôle métier.
- Index sur toutes les FK, memberships, clés tenant/statut/date, versions publiées, échéances, exceptions et files Outbox.
- Recherche catalogue via index texte FR/AR ; pagination serveur, jamais 6 000 questions dans le navigateur.

## Seeds

1. Références : rôles, permissions, scopes, statuts, devises, locales et catégories fiscales.
2. Données demo versionnées : plans, taux fiscal normal Maroc 20 % marqué demo, règle IT 0 droit d’entrée et partage 50/50, autres franchises 50/25/25.
3. Catalogue staging validé par hash/manifeste : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liens, 5 000 questions RFQ, 700 diagnostic et 300 qualification.
4. Scénarios synthétiques V1 et marketing uniquement en local/development/staging.

Les comptes Auth demo sont créés par script Admin avec le mot de passe lu depuis l’environnement, jamais écrit en SQL ou journalisé.

## Procédure d’application distante

1. Vérifier sans afficher de secret que `.env.local` est ignoré et que les variables requises existent.
2. Résoudre le project ref et refuser une cible non explicitement identifiée development/staging.
3. Exécuter reset et tests sur Supabase local.
4. Produire un diff attendu et appliquer les migrations dans l’ordre sur development/staging.
5. Vérifier historique, contraintes, RLS, fonctions, grants, index et comptages de seed.
6. Exécuter tests tenant escape, concurrence, idempotence et smoke applicatif.
7. Enregistrer résultat et hash dans `PROJECT_STATE.md` après gate verte.

Aucune commande destructive, migration ou déploiement de production sans autorisation explicite.

